import AppKit
import SwiftUI
import WebKit

/// KeyCat uses the existing desktop-pet input monitor and window, never its own event tap.
@MainActor
final class KeyCatBridge {
    enum Hit: String { case none, pet, drag }
    static let shared = KeyCatBridge()
    private(set) var hit: Hit = .none
    private var hitSequence: UInt64 = 0
    private var hitRequestPending = false
    private var pressedMouseButtons: Set<Bool> = []
    private var view: WKWebView?
    private weak var settings: PetSettings?
    private var timer: Timer?
    var isAttached: Bool { view != nil }
    private var previousMouse: CGPoint?
    private var lastSleepMinutes: Int?

    func attach(_ webView: WKWebView, settings: PetSettings = .shared) {
        view = webView
        self.settings = settings
        guard let root = Bundle.module.resourceURL?.appendingPathComponent("keycat"),
              FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path) else { return }
        webView.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCursor() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousMouse = nil
        pressedMouseButtons.removeAll()
        hit = .none
        hitSequence &+= 1
        hitRequestPending = false
        lastSleepMinutes = nil
        view?.stopLoading()
        view = nil
        settings = nil
    }

    func resetInput() {
        pressedMouseButtons.removeAll()
        evaluate("window.cat && cat.reset()")
    }

    func setPetting(_ down: Bool, screenPoint: CGPoint) {
        guard let view, let window = view.window else { return }
        let point = view.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        evaluate("window.cat && cat.pet(\(down),\(Int(point.x)))")
    }

    func handleInput(_ event: PetRawEvent) {
        switch event {
        case .keyDown(let code, let repeated):
            if !repeated { key(code, down: true) }
        case .keyUp(let code): key(code, down: false)
        case .flagsChanged(let code, let down): key(code, down: down)
        case .mouseDown(let right):
            pressedMouseButtons.insert(right)
            evaluate("window.cat && cat.mouseButton(true)")
        case .mouseUp(let right):
            pressedMouseButtons.remove(right)
            evaluate("window.cat && cat.mouseButton(\(!pressedMouseButtons.isEmpty))")
        default: break
        }
    }

    private func key(_ code: UInt16, down: Bool) {
        guard let name = KeyCatKeyMap.code(Int(code)) else { return }
        evaluate("window.cat && cat.key('\(name)',\(down))")
    }

    /// 将屏幕坐标转换为网页的左上角坐标；WKWebView 本身通常是 flipped。
    static func pagePoint(fromScreen screenPoint: CGPoint, in view: NSView, window: NSWindow) -> CGPoint {
        let point = view.convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        return CGPoint(x: point.x, y: view.isFlipped ? point.y : view.bounds.height - point.y)
    }

    private func updateCursor() {
        guard let view, let window = view.window, window.isVisible else { return }
        guard let settings else { return }
        if lastSleepMinutes != settings.sleepMinutes {
            let minutes = settings.sleepMinutes
            let seconds = minutes == 0 ? 1_000_000_000 : minutes * 60
            view.evaluateJavaScript("if(window.cat){cat.options({sleepAfter:\(seconds)}); true}else{false}") { [weak self] value, _ in
                if value as? Bool == true { self?.lastSleepMinutes = minutes }
            }
        }
        let mouse = NSEvent.mouseLocation
        let point = view.convert(window.convertPoint(fromScreen: mouse), from: nil)
        let page = Self.pagePoint(fromScreen: mouse, in: view, window: window)
        let x = Int(page.x), y = Int(page.y)
        if !view.bounds.contains(point) {
            hit = .none
            hitSequence &+= 1
            hitRequestPending = false
        } else if !hitRequestPending {
            hitSequence &+= 1
            let sequence = hitSequence
            hitRequestPending = true
            view.evaluateJavaScript("window.cat ? cat.hitTest(\(x),\(y)) : 'none'") { [weak self, weak view] value, _ in
                guard let self, sequence == self.hitSequence else { return }
                self.hitRequestPending = false
                guard let view, let window = view.window else { self.hit = .none; return }
                let current = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
                guard hypot(current.x - point.x, current.y - point.y) < 4 else { self.hit = .none; return }
                self.hit = Hit(rawValue: value as? String ?? "none") ?? .none
            }
        }
        guard !settings.paused else { previousMouse = nil; return }
        var calls: [String] = []
        if settings.followMouse { calls.append("cat.cursor(\(x),\(y))") }
        if let previousMouse {
            let dx = Int(mouse.x - previousMouse.x), dy = Int(previousMouse.y - mouse.y)
            if dx != 0 || dy != 0 { calls.append("cat.mouseMove(\(dx),\(dy))") }
        }
        previousMouse = mouse
        if !calls.isEmpty { evaluate("if (window.cat) { \(calls.joined(separator: ";")) }") }
    }

    private func evaluate(_ script: String) { view?.evaluateJavaScript(script, completionHandler: nil) }
}

struct KeyCatArt: NSViewRepresentable {
    @ObservedObject var settings: PetSettings

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = PetLive2DWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.underPageBackgroundColor = .clear
        KeyCatBridge.shared.attach(view, settings: settings)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {}
    static func dismantleNSView(_ view: WKWebView, coordinator: ()) { KeyCatBridge.shared.stop() }
}
