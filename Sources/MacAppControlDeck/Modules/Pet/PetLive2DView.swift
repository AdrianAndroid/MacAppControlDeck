import AppKit
import SwiftUI
import WebKit

/// 把官方 Live2D 猫模型（Hijiki）跑在桌宠窗口里。
///
/// 分工：Cubism Core 负责网格变形 + 物理 + 动作（这就是"骨骼联动"的来源），
/// 我们只负责把光标/打字/眨眼这三个外部输入换算成参数写进去。
@MainActor
final class PetLive2DBridge {
    static let shared = PetLive2DBridge()

    private(set) var webView: WKWebView
    private let handler = PetL2DSchemeHandler()
    private var timer: Timer?
    private weak var hostWindow: NSWindow?
    private var ready = false
    private var lastMouse: CGPoint = .zero
    private var loadedModel = ""
    private var pressedKeys: [UInt16: UInt64] = [:]
    private var inputSequence: UInt64 = 0
    private var mouseLeftDown = false
    private var mouseRightDown = false

    private init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(handler, forURLScheme: "petl2d")
        config.suppressesIncrementalRendering = false
        webView = PetLive2DWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.clear.cgColor
        webView.underPageBackgroundColor = .clear
        webView.allowsMagnification = false
    }

    static var rootURL: URL? { PetLive2DResources.locate() }
    static var isAvailable: Bool { rootURL != nil }

    func prepare(in window: NSWindow) {
        if window === hostWindow, webView.url != nil { return }
        hostWindow = window
        guard let root = Self.rootURL else { return }
        handler.root = root
        let settings = PetSettings.shared
        loadedModel = settings.live2dModel
        ready = false
        resetInput()
        let q = "?model=\(settings.live2dModel)&tint=\(settings.live2dTint)"
        webView.load(URLRequest(url: URL(string: "petl2d://local/live2d.html" + q)!))
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        resetInput()
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.push() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func push() {
        guard let window = hostWindow, window.isVisible else { return }
        if !ready {
            webView.evaluateJavaScript("!!window.petReady") { [weak self] value, _ in
                MainActor.assumeIsolated {
                    if let ok = value as? Bool, ok {
                        self?.ready = true
                        self?.dumpIds()
                    } else { self?.probeError() }
                }
            }
            return
        }
        write()
    }

    private func dumpIds() {
        webView.evaluateJavaScript("JSON.stringify((window.petIds||[]).slice(0,40))") { value, _ in
            NSLog("[Pet][Live2D] ids=\(value ?? "nil")")
        }
        webView.evaluateJavaScript("JSON.stringify(window.petDebug || {})") { value, _ in
            NSLog("[Pet][Live2D] layout=\(value ?? "nil")")
        }
    }

    private func probeError() {
        webView.evaluateJavaScript("window.petError || ''") { value, _ in
            if let e = value as? String, !e.isEmpty, e != self.lastError {
                self.lastError = e
                NSLog("[Pet][Live2D] \(e)")
            }
        }
    }

    private var lastError: String?

    private func write() {
        guard let window = hostWindow else { return }
        if Self.isBongoModel(loadedModel) {
            writeBongo()
            return
        }
        let frame = window.frame
        let mouse = NSEvent.mouseLocation
        let gx = clamp((mouse.x - frame.midX) / (frame.width * 0.55), -1, 1)
        let gy = clamp((frame.midY - mouse.y) / (frame.height * 0.55), -1, 1)
        lastMouse = CGPoint(x: gx, y: gy)

        let f = PetModuleStateProbe.frame
        let breathe = 0.32 + f.breath * 0.30
        let blink = clamp(f.blink, 0, 1)
        let typing = clamp(abs(f.armLDeg) / 9 + (f.keycaps.isEmpty ? 0 : 0.35), 0, 1)
        let mouth = 0.16 + typing * 0.18 + (f.pawMouse > 0.6 ? 0.22 : 0)
        let js = String(
            format: "petSet({angleX:%.2f,angleY:%.2f,bodyX:%.2f,bodyY:%.2f,eyeBallX:%.2f,eyeBallY:%.2f,breath:%.2f,blink:%.2f,mouth:%.2f,ear:%.2f})",
            gx * 30, gy * 22, gx * 9, gy * 4,
            gx * 0.85, gy * 0.7,
            breathe, blink, mouth, (f.earLDeg + f.earRDeg) * 0.02
        )
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    /// 接收真实物理输入边沿；BongoCat 不再从旧桌宠的动画角度反推爪子状态。
    func handleInput(_ event: PetRawEvent) {
        switch event {
        case .keyDown(let code, _):
            if pressedKeys[code] == nil {
                inputSequence &+= 1
                pressedKeys[code] = inputSequence
            }
        case .keyUp(let code):
            pressedKeys.removeValue(forKey: code)
        case .flagsChanged(let code, let isDown):
            if isDown {
                if pressedKeys[code] == nil {
                    inputSequence &+= 1
                    pressedKeys[code] = inputSequence
                }
            } else {
                pressedKeys.removeValue(forKey: code)
            }
        case .mouseDown(let isRight):
            if isRight { mouseRightDown = true } else { mouseLeftDown = true }
        case .mouseUp(let isRight):
            if isRight { mouseRightDown = false } else { mouseLeftDown = false }
        case .mouseMoved, .scroll:
            break
        }
    }

    func resetInput() {
        pressedKeys.removeAll()
        mouseLeftDown = false
        mouseRightDown = false
    }

    static func isBongoModel(_ model: String) -> Bool {
        model == "bongocat" || model.hasPrefix("bongocat-")
    }

    private func writeBongo() {
        guard let window = hostWindow,
              let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let viewport = screen.frame
        let mouse = NSEvent.mouseLocation
        var x: CGFloat = 0, y: CGFloat = 0
        if PetSettings.shared.followMouse, viewport.width > 0, viewport.height > 0 {
            // 与官方 normalize_position 完全一致：左上为 (+1,+1)，右下为 (-1,-1)。
            x = clamp((viewport.midX - mouse.x) / (viewport.width / 2), -1, 1)
            y = clamp((mouse.y - viewport.midY) / (viewport.height / 2), -1, 1)
        }

        let keyboardMode = loadedModel == "bongocat-keyboard"
        let mapped = pressedKeys.compactMap { element -> (order: UInt64, name: String)? in
            let (code, order) = element
            guard let name = Self.bongoKeyName(for: code, model: loadedModel) else { return nil }
            return (order, name)
        }.sorted { $0.order < $1.order }
        var seen = Set<String>()
        let keys = mapped.filter { seen.insert($0.name).inserted }.map(\.name)
        let handL = mapped.contains { entry in
            !(keyboardMode && Self.bongoArrowNames.values.contains(entry.name))
        }
        let handR = keyboardMode && mapped.contains { Self.bongoArrowNames.values.contains($0.name) }
        let payload: [String: Any] = [
            "pointerX": x,
            "pointerY": y,
            "pointerView": PetGeometry.screenID(for: screen),
            "keys": keys,
            "handL": handL ? 1 : 0,
            "handR": handR ? 1 : 0,
            "mouseLeft": mouseLeftDown ? 1 : 0,
            "mouseRight": mouseRightDown ? 1 : 0
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("petSet(\(json))", completionHandler: nil)
    }

    /// macOS 物理键码 → 官方模型实际携带的键位图文件名。
    /// 没有对应素材的键返回 nil：官方规则是此时爪子也不动。
    static func bongoKeyName(for keyCode: UInt16, model: String) -> String? {
        if let arrow = bongoArrowNames[keyCode] {
            return model == "bongocat-keyboard" ? arrow : nil
        }
        if bongoFunctionKeyCodes.contains(keyCode) { return "Fn" }
        return bongoKeyNames[keyCode]
    }

    private static let bongoArrowNames: [UInt16: String] = [
        123: "LeftArrow", 124: "RightArrow", 125: "DownArrow", 126: "UpArrow"
    ]

    private static let bongoFunctionKeyCodes: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 106, 113
    ]

    private static let bongoKeyNames: [UInt16: String] = [
        0: "KeyA", 1: "KeyS", 2: "KeyD", 3: "KeyF", 4: "KeyH", 5: "KeyG",
        6: "KeyZ", 7: "KeyX", 8: "KeyC", 9: "KeyV", 11: "KeyB", 12: "KeyQ",
        13: "KeyW", 14: "KeyE", 15: "KeyR", 16: "KeyY", 17: "KeyT",
        18: "Num1", 19: "Num2", 20: "Num3", 21: "Num4", 23: "Num5",
        22: "Num6", 26: "Num7", 28: "Num8", 25: "Num9", 29: "Num0",
        31: "KeyO", 32: "KeyU", 34: "KeyI", 35: "KeyP", 36: "Enter",
        37: "KeyL", 38: "KeyJ", 40: "KeyK", 44: "Slash",
        45: "KeyN", 46: "KeyM",
        48: "Tab", 49: "Space", 50: "BackQuote", 51: "Backspace",
        53: "Escape", 54: "Meta", 55: "Meta", 56: "ShiftLeft",
        57: "CapsLock", 58: "AltLeft", 59: "ControlLeft", 60: "ShiftRight",
        61: "AltRight", 62: "ControlRight",
        // 小键盘沿用主键区的重复键素材，与官方 fallback 规则一致。
        75: "Slash", 76: "Enter", 82: "Num0", 83: "Num1", 84: "Num2",
        85: "Num3", 86: "Num4", 87: "Num5", 88: "Num6", 89: "Num7",
        91: "Num8", 92: "Num9", 117: "Delete"
    ]
}

/// 供 bridge 读取当期状态（由模块写入，避免桥反向持有模块）
enum PetModuleStateProbe {
    nonisolated(unsafe) static var frame: PetRasterFrame = .idle
}

final class PetLive2DWebView: WKWebView {
    /// 面板整体点击穿透，网页视图不参与命中测试
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class PetL2DSchemeHandler: NSObject, WKURLSchemeHandler {
    var root: URL?
    private let lock = NSLock()

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              let root, let rel = Self.relativePath(from: url) else {
            task.didFailWithError(NSError(domain: "petl2d", code: 404))
            return
        }
        let file = root.appendingPathComponent(rel)
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: file) else {
            task.didFailWithError(NSError(domain: "petl2d", code: 404))
            return
        }
        let response = URLResponse(url: url,
                                   mimeType: Self.mime(for: rel),
                                   expectedContentLength: data.count,
                                   textEncodingName: rel.hasSuffix(".js") || rel.hasSuffix(".html") ? "utf-8" : nil)
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private static func relativePath(from url: URL) -> String? {
        var s = url.path
        if s.hasPrefix("/") { s.removeFirst() }
        guard !s.contains("..") else { return nil }
        return s.isEmpty ? "live2d.html" : s
    }

    private static func mime(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "html": return "text/html"
        case "js": return "text/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "moc3": return "application/octet-stream"
        default: return "application/octet-stream"
        }
    }
}

enum PetLive2DResources {
    static func locate() -> URL? {
        var candidates: [URL] = []
        if let res = Bundle.module.resourceURL { candidates.append(res.appendingPathComponent("live2d")) }
        let bundleName = "MacAppControlDeck_MacAppControlDeck.bundle"
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent(bundleName).appendingPathComponent("live2d"))
            candidates.append(res.appendingPathComponent("live2d"))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
            .appendingPathComponent(bundleName).appendingPathComponent("live2d"))
        for url in candidates where FileManager.default.fileExists(atPath: url.appendingPathComponent("live2d.html").path) {
            return url
        }
        return nil
    }
}

struct PetLive2DArt: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let view = PetLive2DBridge.shared.webView
        DispatchQueue.main.async {
            if let window = view.window { PetLive2DBridge.shared.prepare(in: window) }
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let window = nsView.window {
            nsView.setValue(false, forKey: "drawsBackground")
            nsView.layer?.backgroundColor = NSColor.clear.cgColor
            PetLive2DBridge.shared.prepare(in: window)
        }
    }
}
