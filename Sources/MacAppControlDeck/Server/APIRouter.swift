import AppKit
import Foundation

struct HTTPResponse {
    var status: Int
    var contentType: String
    var body: Data
    var headers: [String: String] = [:]
    var rawHeaders: [String: String] = [:]

    static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(value)) ?? Data("{}".utf8)
        return HTTPResponse(status: status, contentType: "application/json; charset=utf-8", body: data)
    }

    static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/plain; charset=utf-8", body: Data(string.utf8))
    }

    static func html(_ string: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, contentType: "text/html; charset=utf-8", body: Data(string.utf8))
    }

    static func error(_ code: String, message: String, status: Int) -> HTTPResponse {
        struct E: Encodable { let error: String; let message: String }
        return json(E(error: code, message: message), status: status)
    }

    static func statusText(_ status: Int) -> String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 302: return "Found"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 413: return "Payload Too Large"
        case 415: return "Unsupported Media Type"
        case 500: return "Internal Server Error"
        default: return "Status"
        }
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]
    var body: Data

    func header(_ name: String) -> String? {
        if let value = headers[name] { return value }
        return headers.first { $0.key.lowercased() == name.lowercased() }?.value
    }
}

final class APIRouter {
    let store: ConfigStore
    let pairing: PairingManager
    let activator: AppControlling
    let injector: ShortcutInjecting
    private let iconDirectory: URL
    private let maxBodySize = 4096
    private let quickActionQueue = DispatchQueue(label: "deck.quick-actions", qos: .userInitiated)
    private let logger = RequestLogger.shared

    init(store: ConfigStore,
         pairing: PairingManager,
         activator: AppControlling,
         injector: ShortcutInjecting = KeyInjector(),
         iconDirectory: URL? = nil) {
        self.store = store
        self.pairing = pairing
        self.activator = activator
        self.injector = injector
        self.iconDirectory = iconDirectory ?? ConfigStore.defaultDirectory().appendingPathComponent("icons")
        try? FileManager.default.createDirectory(at: self.iconDirectory, withIntermediateDirectories: true)
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let path = normalizedPath(request.path)

        guard request.method == "GET" || request.method == "POST" else {
            return .error("method-not-allowed", message: "仅支持 GET/POST", status: 405)
        }
        guard request.body.count <= maxBodySize else {
            return .error("payload-too-large", message: "请求体过大", status: 413)
        }

        // 面板入口强制带版本参数，避免 Web App / Safari 使用旧缓存页面
        if request.method == "GET",
           request.path == "/panel" || request.path == "/panel/" || request.path == "/panel/index.html" {
            var resp = HTTPResponse(status: 302, contentType: "text/plain; charset=utf-8", body: Data())
            resp.headers["Location"] = "/panel/?v=\(PanelHTML.version)"
            resp.headers["Cache-Control"] = "no-store, must-revalidate"
            return resp
        }

        if let host = request.header("Host"), !HostPolicy.isAllowed(host) {
            return .error("bad-host", message: "拒绝的请求来源", status: 403)
        }

        switch (request.method, path) {
        case ("GET", "/api/panel-version"):
            struct PanelVersion: Codable { let version: String }
            return .json(PanelVersion(version: PanelHTML.version))
        case ("GET", "/api/health"):
            struct Health: Codable { let ok: Bool; let app: String; let version: String }
            return .json(Health(ok: true, app: "MacAppControlDeck", version: "0.1.0"))
        case ("POST", "/api/pair"):
            return await handlePair(request)
        case ("GET", "/api/buttons"):
            return await withAuth(request) { _ in handleButtons() }
        case ("POST", "/api/activate"):
            return await withAuth(request) { _ in await handleActivate(request) }
        default:
            return handleStatic(path: path)
        }
    }

    private func normalizedPath(_ rawPath: String) -> String {
        if let index = rawPath.range(of: "?") {
            return String(rawPath[..<(index.lowerBound)])
        }
        return rawPath
    }

    private func withAuth(_ request: HTTPRequest,
                          _ handler: (DeviceRecord) async -> HTTPResponse) async -> HTTPResponse {
        var token: String?
        if let auth = request.header("Authorization"), auth.hasPrefix("Bearer ") {
            token = String(auth.dropFirst("Bearer ".count))
        } else if let headerToken = request.header("X-Device-Token") {
            token = headerToken
        }
        guard let token, !token.isEmpty, let device = store.device(token: token) else {
            return .error("unauthorized", message: "凭证无效或未配对", status: 401)
        }
        return await handler(device)
    }

    private func handlePair(_ request: HTTPRequest) async -> HTTPResponse {
        struct Payload: Codable { var code: String; var deviceName: String }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: request.body) else {
            return .error("bad-request", message: "请求格式错误", status: 400)
        }
        switch pairing.redeem(payload.code) {
        case .ok:
            let token = PairingManager.generateToken()
            let name = payload.deviceName.isEmpty ? "未命名设备" : payload.deviceName
            store.addDevice(token: token, name: name)
            logger.log(endpoint: "/api/pair", result: "paired-\(name)", token: nil, code: nil)
            struct Resp: Codable { var token: String; var deviceName: String }
            return .json(Resp(token: token, deviceName: name))
        case .wrongCode:
            logger.log(endpoint: "/api/pair", result: "wrong-code", token: nil, code: nil)
            return .error("wrong-code", message: "配对码错误", status: 403)
        case .expired:
            return .error("expired", message: "配对码已过期，请在 Mac 端重新生成", status: 403)
        case .locked:
            return .error("locked", message: "错误次数过多，配对码已作废，请在 Mac 端重新生成", status: 403)
        case .noActiveCode:
            return .error("no-active-code", message: "请先在 Mac 端生成配对码", status: 403)
        }
    }

    private func handleButtons() -> HTTPResponse {
        struct ButtonDTO: Codable {
            var id: String
            var kind: String
            var name: String
            var bundleID: String
            var installed: Bool
            var iconUrl: String?
            var symbol: String?
        }
        struct Resp: Codable { var buttons: [ButtonDTO] }

        let buttons = store.sortedButtons()
        let dtos = buttons.map { button -> ButtonDTO in
            guard button.kind == .app else {
                return ButtonDTO(id: button.id,
                                 kind: button.kind.rawValue,
                                 name: button.name,
                                 bundleID: "",
                                 installed: true,
                                 iconUrl: nil,
                                 symbol: button.kind == .command
                                     ? "▶"
                                     : (button.kind == .builtin
                                        ? BuiltinActions.symbol(for: button.builtinAction)
                                        : button.displaySymbol))
            }
            var url: String?
            let hasIcon = IconCache.cachedIconURL(appPath: button.appPath,
                                                  cacheURL: iconDirectory.appendingPathComponent("\(button.id).png")) != nil
            if hasIcon {
                url = "/icons/\(button.id).png"
            }
            let installed = FileManager.default.fileExists(atPath: button.appPath)
                || !NSWorkspaceLike.bundleURLs(for: button.bundleID).isEmpty
            return ButtonDTO(id: button.id,
                             kind: ButtonKind.app.rawValue,
                             name: button.name,
                             bundleID: button.bundleID,
                             installed: installed,
                             iconUrl: url,
                             symbol: nil)
        }
        return .json(Resp(buttons: dtos))
    }

    private func handleActivate(_ request: HTTPRequest) async -> HTTPResponse {
        struct Payload: Codable { var buttonId: String }
        guard request.header("Content-Type")?.lowercased().contains("application/json") != false else {
            return .error("unsupported-media-type", message: "Content-Type 须为 application/json", status: 415)
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: request.body),
              !payload.buttonId.isEmpty else {
            return .error("bad-request", message: "请求格式错误，需要 buttonId", status: 400)
        }
        guard let button = store.button(id: payload.buttonId) else {
            return .error("button-not-found", message: "按钮不存在", status: 404)
        }
        switch button.kind {
        case .app:
            let outcome = await activator.activate(bundleID: button.bundleID)
            struct Resp: Codable { var status: ActivateStatus; var message: String }
            return .json(Resp(status: outcome.status, message: outcome.message))
        case .shortcut:
            guard let combo = button.shortcut else {
                return .error("bad-button-config", message: "快捷操作配置不完整，请在 Mac 端重新编辑", status: 409)
            }
            // 串行执行：连续点击（如连续切换桌面）时保证按键顺序
            let result: ShortcutInjectionResult = quickActionQueue.sync {
                injector.inject(combo)
            }
            guard result.sent else {
                return .error(result.errorCode ?? "injection-failed",
                              message: result.message,
                              status: 403)
            }
            struct Resp: Codable { var status: ActivateStatus; var message: String }
            return .json(Resp(status: .sent, message: result.message))
        case .builtin:
            guard let action = button.builtinAction else {
                return .error("bad-button-config", message: "内置操作配置不完整", status: 409)
            }
            let result: (ok: Bool, message: String) = quickActionQueue.sync {
                BuiltinActions.run(action)
            }
            guard result.ok else {
                return .error("builtin-failed", message: result.message, status: 403)
            }
            struct Resp: Codable { var status: ActivateStatus; var message: String }
            return .json(Resp(status: .sent, message: result.message))
        case .command:
            guard !button.appPath.isEmpty else {
                return .error("bad-button-config", message: "命令按钮配置不完整", status: 409)
            }
            let result: CommandRunResult = quickActionQueue.sync {
                CommandRunner.run(appPath: button.appPath,
                                  arguments: button.commandArguments ?? [])
            }
            guard result.ok else {
                return .error("command-failed", message: result.message, status: 403)
            }
            struct Resp: Codable { var status: ActivateStatus; var message: String }
            return .json(Resp(status: .sent, message: result.message))
        }
    }

    private func handleStatic(path: String) -> HTTPResponse {
        let route = path == "/" ? "/panel/" : path

        if route == "/panel" || route == "/panel/" {
            var response = HTTPResponse.html(PanelHTML.content)
            // 面板改版后 Safari 必须立即拿到新版本（避免旧缓存导致布局问题复现）
            response.headers["Cache-Control"] = "no-store, must-revalidate"
            response.rawHeaders["Cache-Control"] = "no-store, must-revalidate"
            return response
        }
        if route.hasPrefix("/icons/") {
            let name = String(route.dropFirst("/icons/".count))
            let fileURL = iconDirectory.appendingPathComponent(name)
            guard name == (name as NSString).lastPathComponent,
                  let data = try? Data(contentsOf: fileURL) else {
                return .error("not-found", message: "图标不存在", status: 404)
            }
            return HTTPResponse(status: 200, contentType: "image/png", body: data,
                                headers: ["Cache-Control": "max-age=3600"])
        }
        if route == "/apple-touch-icon.png" {
            if let data = GeneratedIcon.appleTouchIconPNG() {
                return HTTPResponse(status: 200, contentType: "image/png", body: data,
                                    headers: ["Cache-Control": "max-age=86400"])
            }
            return .error("not-found", message: "未找到", status: 404)
        }
        return .error("not-found", message: "路径不存在", status: 404)
    }
}

enum HostPolicy {
    /// 防 DNS rebinding：只接受"指向本机"的 Host——
    /// 本机各局域网 IPv4、回环、私有/链路本地 IP 字面量、localhost 与 .local 名称。
    /// 不再固定比较单一 en0 地址，避免 Wi-Fi(en1) 或手输正确 IP 被误拒。
    static func isAllowed(_ rawHost: String) -> Bool {
        let host = stripPort(rawHost).lowercased()
        guard !host.isEmpty else { return false }
        if host == "localhost" { return true }
        if host.hasSuffix(".local") { return true }
        if LANAddress.localIPv4s().contains(host) { return true }
        if isLoopbackOrLocalIPv4(host) { return true }
        if isLocalIPv6(host) { return true }
        return false
    }

    private static func stripPort(_ raw: String) -> String {
        if raw.hasPrefix("[") {                       // [IPv6]:port
            guard let end = raw.firstIndex(of: "]") else { return raw }
            return String(raw[raw.index(after: raw.startIndex)..<end])
        }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, parts[1].allSatisfy({ $0.isNumber }) {
            return String(parts[0])                   // IPv4:port
        }
        return raw
    }

    private static func isLoopbackOrLocalIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4, host.split(separator: ".").count == 4 else { return false }
        switch (parts[0], parts[1]) {
        case (127, _), (10, _), (192, 168), (169, 254): return true
        case (172, 16...31): return true
        default: return false
        }
    }

    private static func isLocalIPv6(_ host: String) -> Bool {
        guard host.contains(":") else { return false }
        if host == "::1" { return true }
        if host.hasPrefix("fe80:") || host.hasPrefix("fe80::") { return true }
        if host.hasPrefix("fc") || host.hasPrefix("fd") { return true }   // ULA fc00::/7
        return false
    }
}

enum NSWorkspaceLike {
    static func bundleURLs(for bundleID: String) -> [URL] {
        NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleID)
    }
}

final class RequestLogger {
    static let shared = RequestLogger()
    private let queue = DispatchQueue(label: "deck.logger", qos: .utility)
    private var entries: [String] = []

    func log(endpoint: String, result: String, token: String?, code: String?) {
        queue.sync {
            let line = "[\(Date())] \(endpoint) -> \(result)"
            entries.append(line)
            print(line)
        }
    }
}

enum GeneratedIcon {
    static func appleTouchIconPNG(size: CGFloat = 180) -> Data? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.75, alpha: 1).setFill()
        let rect = NSRect(origin: .zero, size: NSSize(width: size, height: size)).insetBy(dx: 8, dy: 8)
        NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size * 0.44, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let string = NSAttributedString(string: "D", attributes: attributes)
        let textSize = string.size()
        string.draw(at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return png
    }
}
