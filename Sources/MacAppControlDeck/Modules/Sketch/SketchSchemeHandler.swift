import Foundation
import WebKit

/// 把 Excalidraw 静态资源放在 deck-sketch://local/ 下，避免 file:// 的目录和模块限制。
final class SketchSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "deck-sketch"
    static let host = "local"

    let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    static func resourceRoot() -> URL? {
        let bundleName = "MacAppControlDeck_MacAppControlDeck.bundle"
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent(bundleName).appendingPathComponent("Sketch"))
            candidates.append(resources.appendingPathComponent("Sketch"))
        }
        candidates.append(
            Bundle.main.bundleURL.appendingPathComponent(bundleName).appendingPathComponent("Sketch")
        )
        for url in candidates {
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("index.html").path) {
                return url
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else {
            task.didFailWithError(Self.error(404))
            return
        }

        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let relative = String(path.dropFirst()).removingPercentEncoding ?? String(path.dropFirst())
        let target = root.appendingPathComponent(relative).standardizedFileURL

        guard target.path == root.path || target.path.hasPrefix(root.path + "/") else {
            task.didFailWithError(Self.error(403))
            return
        }
        guard let data = try? Data(contentsOf: target) else {
            task.didFailWithError(Self.error(404))
            return
        }

        let mime = Self.mimeType(for: target.pathExtension)
        let response = URLResponse(
            url: url,
            mimeType: mime,
            expectedContentLength: data.count,
            textEncodingName: Self.isText(mime) ? "utf-8" : nil
        )
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private static func mimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    private static func isText(_ mime: String) -> Bool {
        mime.hasPrefix("text/") || mime == "application/json"
    }

    private static func error(_ code: Int) -> NSError {
        NSError(
            domain: "SketchSchemeHandler",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: code == 403 ? "禁止访问该路径" : "资源不存在"]
        )
    }
}
