import AppKit
import Foundation
import WebKit

/// sketch 模块唯一的窗口：懒加载 WKWebView，关闭时落草稿并释放网页进程。
@MainActor
final class SketchWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate,
    SketchBridgeDelegate {
    static let shared = SketchWindowController()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var bridge: SketchBridge?
    private var schemeHandler: SketchSchemeHandler?
    private var isReady = false
    private var isLoadingBoard = false
    private var isClosing = false
    private var pendingAction: PendingAction?
    private var pendingOpenURL: URL?

    private let settings = SketchSettings.shared
    private let store = SketchStore.shared

    private enum PendingAction {
        case copy
        case save
        case new
    }

    private override init() { super.init() }

    var isOpen: Bool {
        window?.isVisible == true
    }

    var isBoardReady: Bool {
        isReady
    }

    // MARK: - 打开 / 关闭

    func show() {
        if let window {
            applyAlwaysOnTop()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let root = SketchSchemeHandler.resourceRoot() else {
            showAlert(title: "UI 草图资源缺失", message: "安装包里没有找到 Excalidraw 静态资源，请重新构建安装。")
            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.isElementFullscreenEnabled = false
        let bridge = SketchBridge()
        bridge.delegate = self
        configuration.userContentController.add(bridge, name: SketchBridge.name)

        let schemeHandler = SketchSchemeHandler(root: root)
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: SketchSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "UI 草图"
        window.subtitle = "鼠标画 UI 意图，复制后直接粘贴给 AI"
        window.contentView = webView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 820, height: 560)
        if let savedFrame = settings.windowFrame {
            window.setFrame(savedFrame, display: false)
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
        self.webView = webView
        self.bridge = bridge
        self.schemeHandler = schemeHandler
        applyAlwaysOnTop()

        installNetworkBlock { [weak self] in
            guard let self, let webView = self.webView else { return }
            webView.load(URLRequest(url: URL(string: "deck-sketch://local/index.html")!))
        }
    }

    /// 模块被关闭时立即收起窗口并释放网页。
    func shutdown() {
        pendingAction = nil
        pendingOpenURL = nil
        guard let window else {
            destroyWebView()
            return
        }
        window.delegate = nil
        window.orderOut(nil)
        window.close()
        self.window = nil
        destroyWebView()
        isReady = false
        isLoadingBoard = false
    }

    func applyAlwaysOnTop() {
        window?.level = settings.alwaysOnTop ? .floating : .normal
    }

    private func installNetworkBlock(completion: @escaping @MainActor () -> Void) {
        let rules = """
        [
          {"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
          {"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}},
          {"trigger":{"url-filter":"^ftp://"},"action":{"type":"block"}}
        ]
        """
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "SketchBlockNetwork",
            encodedContentRuleList: rules
        ) { [weak self] list, error in
            Task { @MainActor in
                if let error {
                    NSLog("[sketch] 网络拦截规则编译失败: \(error.localizedDescription)")
                }
                if let list {
                    self?.webView?.configuration.userContentController.add(list)
                }
                completion()
            }
        }
    }

    private func destroyWebView() {
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: SketchBridge.name)
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView = nil
        bridge = nil
        schemeHandler = nil
    }

    // MARK: - 桥接事件

    func sketchBridge(_ bridge: SketchBridge, didReceive event: SketchBridgeEvent) {
        switch event {
        case .ready:
            handleReady()
        case .change(let scene):
            store.saveDraft(scene)
        case .copyRequested:
            copyCurrentSketch()
        case .saveRequested:
            saveCurrentSketch()
        case .newRequested:
            newBoard()
        }
    }

    private func handleReady() {
        guard !isLoadingBoard else { return }
        isLoadingBoard = true
        isReady = true

        Task {
            do {
                if let pendingOpenURL {
                    self.pendingOpenURL = nil
                    try await loadScene(from: pendingOpenURL, rememberDraft: true)
                } else {
                    let draft = store.loadDraft() ?? ""
                    try await callJS(
                        "window.deckSketch.loadScene(json); return true;",
                        arguments: ["json": draft]
                    )
                }
            } catch {
                NSLog("[sketch] 加载草稿失败: \(error.localizedDescription)")
                toast("草稿读取失败，已打开空白画板", kind: "error")
            }
            isLoadingBoard = false
            runPendingActionIfNeeded()
        }
    }

    private func runPendingActionIfNeeded() {
        guard isReady, let pendingAction else { return }
        self.pendingAction = nil
        switch pendingAction {
        case .copy: copyCurrentSketch()
        case .save: saveCurrentSketch()
        case .new: newBoard()
        }
    }

    // MARK: - 复制

    func copyCurrentSketch() {
        guard isReady else {
            pendingAction = .copy
            show()
            return
        }
        Task {
            do {
                guard try await hasContent() else { throw SketchError.emptyBoard }
                let export = try await exportPNG()
                debugLog("[sketch] exported \(export.width)x\(export.height), selected=\(export.selected)")
                guard store.writeClipboard(pngData: export.data) else {
                    throw SketchError.exportFailed("写入剪贴板失败")
                }
                debugLog("[sketch] clipboard written, bytes=\(export.data.count)")
                let message = export.selected
                    ? "已复制选中内容，可直接粘贴给 AI"
                    : "已复制整个画板，可直接粘贴给 AI"
                toast(message)
            } catch {
                debugLog("[sketch] copy failed: \(error)")
                toast(message(for: error), kind: "error")
            }
        }
    }

    // MARK: - 保存

    func saveCurrentSketch() {
        guard isReady else {
            pendingAction = .save
            show()
            return
        }
        Task {
            do {
                guard try await hasContent() else { throw SketchError.emptyBoard }
                let sceneValue = try await evalJS("window.deckSketch.getScene()")
                guard let scene = sceneValue as? String else {
                    throw SketchError.exportFailed("读取画板源文件失败")
                }
                let exported = try await exportPNG()
                let saved = try store.save(sceneJSON: scene, pngData: exported.data)
                toast("已保存 \(saved.pngURL.lastPathComponent)")
            } catch {
                toast(message(for: error), kind: "error")
            }
        }
    }

    // MARK: - 新建 / 打开

    func newBoard() {
        guard isReady else {
            store.clearDraft()
            pendingAction = .new
            show()
            return
        }
        Task {
            do {
                if try await hasContent(), !confirmNewBoard() {
                    return
                }
                try await callJS("window.deckSketch.clear(); return true;")
                store.clearDraft()
                toast("已新建空白画板")
            } catch {
                toast(message(for: error), kind: "error")
            }
        }
    }

    func openSketch(at url: URL) {
        if !isReady || !isOpen {
            pendingOpenURL = url
            show()
            return
        }
        Task {
            do {
                try await loadScene(from: url, rememberDraft: true)
                toast("已打开 \(url.lastPathComponent)")
            } catch {
                toast(message(for: error), kind: "error")
            }
        }
    }

    private func loadScene(from url: URL, rememberDraft: Bool) async throws {
        let json = try String(contentsOf: url, encoding: .utf8)
        _ = try await callJS(
            "window.deckSketch.loadScene(json); return true;",
            arguments: ["json": json]
        )
        if rememberDraft {
            store.saveDraft(json)
        }
    }

    private func confirmNewBoard() -> Bool {
        let alert = NSAlert()
        alert.messageText = "新建空白画板？"
        alert.informativeText = "当前画板会被清空。已经保存的 PNG 和 .excalidraw 文件不受影响。"
        alert.addButton(withTitle: "新建")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - JS 调用

    private func callJS(_ body: String, arguments: [String: Any] = [:]) async throws -> Any? {
        guard let webView, isReady else { throw SketchError.webUnavailable }
        return try await webView.callAsyncJavaScript(
            body,
            arguments: arguments,
            in: nil,
            in: .page
        )
    }

    private func evalJS(_ script: String) async throws -> Any? {
        guard let webView, isReady else { throw SketchError.webUnavailable }
        return try await webView.evaluateJavaScript(script)
    }

    private func hasContent() async throws -> Bool {
        let value = try await evalJS("window.deckSketch.getScene()")
        guard let value else {
            debugLog("[sketch] hasContent: JS returned nil")
            return false
        }
        guard let scene = value as? String,
              let data = scene.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = json["elements"] as? [Any] else {
            debugLog("[sketch] hasContent: scene is not expected JSON")
            return false
        }
        return !elements.isEmpty
    }

    private struct ExportResult {
        let data: Data
        let selected: Bool
        let width: Int
        let height: Int
    }

    private func exportPNG() async throws -> ExportResult {
        let scale = settings.exportScale
        let background = settings.exportBackground.rawValue
        _ = try await evalJS(
            """
            window.__deckExport = null;
            window.deckSketch.exportPNG(\(scale), 24, "\(background)")
              .then(function (result) { window.__deckExport = result; })
              .catch(function (error) { window.__deckExport = { error: String(error) }; });
            true;
            """
        )

        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            let raw = try await evalJS("window.__deckExport ? JSON.stringify(window.__deckExport) : ''")
            guard let text = raw as? String, !text.isEmpty else { continue }
            _ = try? await evalJS("window.__deckExport = null")
            guard let data = text.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SketchError.exportFailed("导出结果格式异常")
            }
            if let error = dict["error"] as? String {
                throw SketchError.exportFailed(error)
            }
            guard let base64 = dict["base64"] as? String,
                  let png = Data(base64Encoded: base64) else {
                throw SketchError.exportFailed("导出结果格式异常")
            }
            let width = (dict["width"] as? NSNumber)?.intValue ?? 0
            let height = (dict["height"] as? NSNumber)?.intValue ?? 0
            let selected = (dict["selected"] as? Bool)
                ?? (dict["selected"] as? NSNumber)?.boolValue
                ?? false
            return ExportResult(data: png, selected: selected, width: width, height: height)
        }
        throw SketchError.exportFailed("导出超时，请缩小画板内容后重试")
    }

    private func toast(_ text: String, kind: String = "ok") {
        Task {
            _ = try? await callJS(
                "window.deckSketch.showToast(text, kind); return true;",
                arguments: ["text": text, "kind": kind]
            )
        }
    }

    private func message(for error: Error) -> String {
        if let sketchError = error as? SketchError {
            return sketchError.localizedDescription
        }
        let text = error.localizedDescription
        if text.contains("画板还是空的") { return "画板还是空的，先画点内容" }
        return text
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    // MARK: - 窗口代理

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !isClosing else { return true }
        isClosing = true
        sender.orderOut(nil)
        Task {
            await flushDraft()
            self.teardownAfterClose()
        }
        return false
    }

    private func flushDraft() async {
        guard isReady else { return }
        if let scene = try? await callJS("return window.deckSketch.getScene();") as? String,
           !scene.isEmpty {
            store.saveDraft(scene)
        }
    }

    private func teardownAfterClose() {
        if let window {
            window.delegate = nil
            window.close()
        }
        window = nil
        destroyWebView()
        isReady = false
        isLoadingBoard = false
        pendingAction = nil
        isClosing = false
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    private func saveFrame() {
        guard let window, window.isVisible else { return }
        settings.windowFrame = window.frame
    }

    // MARK: - 导航限制

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        if url.scheme == SketchSchemeHandler.scheme {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        if ["http", "https", "mailto"].contains(url.scheme ?? "") {
            NSWorkspace.shared.open(url)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url,
           ["http", "https", "mailto"].contains(url.scheme ?? "") {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[sketch] 页面加载失败: \(error.localizedDescription)")
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        NSLog("[sketch] 页面初始加载失败: \(error.localizedDescription)")
    }
}
