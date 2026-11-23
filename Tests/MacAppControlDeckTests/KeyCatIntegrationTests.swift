import AppKit
import WebKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class KeyCatIntegrationTests: XCTestCase {
    private var window: NSWindow!
    private var webView: WKWebView!

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 288, height: 294),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = PetLive2DWebView(frame: window.contentView!.bounds, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        window.contentView = webView
        window.orderFrontRegardless()
        KeyCatBridge.shared.attach(webView)
    }

    override func tearDown() {
        KeyCatBridge.shared.stop()
        window.close()
        webView = nil
        window = nil
        super.tearDown()
    }

    private func evaluate(_ script: String, file: StaticString = #filePath, line: UInt = #line) -> Any? {
        let done = expectation(description: "JavaScript: \(script)")
        var result: Any?
        webView.evaluateJavaScript(script) { value, error in
            if let error { XCTFail("JavaScript error: \(error)", file: file, line: line) }
            result = value
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return result
    }

    private func waitForScene(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if evaluate("!!window.cat", file: file, line: line) as? Bool == true { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("KeyCat scene did not load", file: file, line: line)
        return false
    }

    func testScreenCoordinatesDriveEyesInAllFourDirections() {
        guard waitForScene() else { return }
        // 停止真实鼠标定时推送，保留 WebView 运行，以便对同一场景输入可复现坐标。
        KeyCatBridge.shared.stop()
        let center = CGPoint(x: window.frame.midX, y: window.frame.midY)
        func page(_ screen: CGPoint) -> CGPoint {
            KeyCatBridge.pagePoint(fromScreen: screen, in: webView, window: window)
        }
        let up = page(CGPoint(x: center.x, y: center.y + 100))
        let down = page(CGPoint(x: center.x, y: center.y - 100))
        let left = page(CGPoint(x: center.x - 100, y: center.y))
        let right = page(CGPoint(x: center.x + 100, y: center.y))
        XCTAssertLessThan(up.y, down.y, "网页坐标向下增长，屏幕上方应是较小 y")
        XCTAssertLessThan(left.x, right.x)
        let outside = page(CGPoint(x: center.x, y: center.y + 1000))
        XCTAssertLessThan(outside.y, 0, "窗口外的光标仍须保持方向")
        let initialOrigin = window.frame.origin
        window.setFrameOrigin(CGPoint(x: initialOrigin.x + 40, y: initialOrigin.y + 30))
        let movedCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        let movedUp = page(CGPoint(x: movedCenter.x, y: movedCenter.y + 100))
        XCTAssertEqual(movedUp.y, up.y, accuracy: 0.01, "移动窗口不得改变局部坐标")

        func gaze(_ point: CGPoint) -> [Double] {
            _ = evaluate("cat.reset(); cat.state.nextAct=1e12; cat.cursor(\(point.x),\(point.y))")
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            return evaluate("""
            K.scene.updateMatrixWorld(true);
            (()=>{const e=K.cat.eyes[0]; const p=e.pupil.getWorldPosition(new THREE.Vector3()).project(K.camera); const i=e.iris.getWorldPosition(new THREE.Vector3()).project(K.camera); return [p.x-i.x,p.y-i.y]})()
            """) as? [Double] ?? []
        }
        let leftGaze = gaze(page(CGPoint(x: movedCenter.x - 1000, y: movedCenter.y)))
        let rightGaze = gaze(page(CGPoint(x: movedCenter.x + 1000, y: movedCenter.y)))
        let upGaze = gaze(page(CGPoint(x: movedCenter.x, y: movedCenter.y + 1000)))
        let downGaze = gaze(page(CGPoint(x: movedCenter.x, y: movedCenter.y - 1000)))
        guard [leftGaze, rightGaze, upGaze, downGaze].allSatisfy({ $0.count == 2 }) else {
            return XCTFail("无法读取眼睛渲染坐标")
        }
        XCTAssertLessThan(leftGaze[0], rightGaze[0], "屏幕上的瞳孔应左右跟随")
        XCTAssertGreaterThan(upGaze[1], downGaze[1], "屏幕上的瞳孔应上下跟随")

        let head = evaluate("""
        (()=>{for(let x=0;x<innerWidth;x+=4) for(let y=0;y<innerHeight;y+=4) if(cat.hitTest(x,y)==='pet') return [x,y]; return []})()
        """) as? [Double] ?? []
        guard head.count == 2 else { return XCTFail("未找到头部命中区域") }
        let viewPoint = CGPoint(x: head[0], y: head[1])
        let screenPoint = window.convertPoint(toScreen: webView.convert(viewPoint, to: nil))
        let hitPoint = page(screenPoint)
        XCTAssertEqual(hitPoint.x, head[0], accuracy: 0.01)
        XCTAssertEqual(hitPoint.y, head[1], accuracy: 0.01)
        XCTAssertEqual(evaluate("cat.hitTest(\(hitPoint.x),\(hitPoint.y))") as? String, "pet")
    }

    func testSceneLoadsRendersAndRespondsToInput() {
        guard waitForScene() else { return }
        XCTAssertEqual(evaluate("document.querySelectorAll('canvas').length") as? Int, 1)
        KeyCatBridge.shared.handleInput(.keyDown(0, isRepeat: false))
        XCTAssertEqual(evaluate("cat.state.strokes.length") as? Int, 1)
        KeyCatBridge.shared.handleInput(.keyUp(0))
        KeyCatBridge.shared.handleInput(.mouseDown(isRight: false))
        XCTAssertEqual(evaluate("cat.state.mouseDown") as? Bool, true)
        KeyCatBridge.shared.handleInput(.mouseDown(isRight: true))
        KeyCatBridge.shared.handleInput(.mouseUp(isRight: false))
        XCTAssertEqual(evaluate("cat.state.mouseDown") as? Bool, true)
        KeyCatBridge.shared.handleInput(.mouseUp(isRight: true))
        XCTAssertEqual(evaluate("cat.state.mouseDown") as? Bool, false)
        KeyCatBridge.shared.setPetting(true, screenPoint: window.convertPoint(toScreen: NSPoint(x: 140, y: 180)))
        XCTAssertEqual(evaluate("cat.state.petting") as? Bool, true)
        KeyCatBridge.shared.setPetting(false, screenPoint: .zero)
        XCTAssertEqual(evaluate("cat.state.petting") as? Bool, false)
        let hits = evaluate("let n=0; for(let x=0;x<innerWidth;x+=12) for(let y=0;y<innerHeight;y+=12) if(cat.hitTest(x,y)!=='none') n++; n") as? Int ?? 0
        XCTAssertGreaterThan(hits, 0, "scene should have interactive cat or keyboard geometry")
        XCTAssertEqual(evaluate("cat.hitTest(-100,-100)") as? String, "none")

        let snapshotDone = expectation(description: "rendered KeyCat snapshot")
        webView.takeSnapshot(with: nil) { image, error in
            XCTAssertNil(error)
            guard let image, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else {
                XCTFail("missing scene snapshot")
                snapshotDone.fulfill()
                return
            }
            if let path = ProcessInfo.processInfo.environment["DECK_PET_TEST_SNAPSHOT"],
               let png = bitmap.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            var nonTransparent = 0
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 8) {
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: 8) {
                    if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.1 { nonTransparent += 1 }
                }
            }
            XCTAssertGreaterThan(nonTransparent, 30, "KeyCat must render visible pixels")
            XCTAssertLessThan(bitmap.colorAt(x: 0, y: 0)?.alphaComponent ?? 1, 0.1, "background must be transparent")
            snapshotDone.fulfill()
        }
        wait(for: [snapshotDone], timeout: 10)
    }
}

@MainActor
final class PetSwitchIntegrationTests: XCTestCase {
    private func waitUntil(_ description: String, timeout: TimeInterval = 3, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("Timed out waiting for \(description)")
    }

    private func webViews(in view: NSView) -> [WKWebView] {
        (view as? WKWebView).map { [$0] } ?? view.subviews.flatMap { webViews(in: $0) }
    }

    private func evaluate(_ script: String, in webView: WKWebView) -> Any? {
        let done = expectation(description: script)
        var result: Any?
        webView.evaluateJavaScript(script) { value, error in
            XCTAssertNil(error)
            result = value
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return result
    }

    func testKeyCatSizesPauseInputResetAndReopen() {
        _ = NSApplication.shared
        let suite = "pet-lifecycle-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PetSettings(defaults: defaults)
        settings.kind = .keyCat
        let runtime = PetRuntime(settings: settings)
        defer { runtime.shutdown() }
        runtime.start()
        runtime.show()
        waitUntil("KeyCat panel") { NSApplication.shared.windows.contains { $0 is PetPanel && $0.isVisible } }
        guard let panel = NSApplication.shared.windows.first(where: { $0 is PetPanel && $0.isVisible }),
              let content = panel.contentView else { return XCTFail("pet panel missing") }
        waitUntil("KeyCat view") { self.webViews(in: content).contains { $0.url?.lastPathComponent == "index.html" } }
        guard let webView = webViews(in: content).first(where: { $0.url?.lastPathComponent == "index.html" }) else {
            return XCTFail("KeyCat view missing")
        }
        waitUntil("KeyCat scene ready") { self.evaluate("!!window.cat", in: webView) as? Bool == true }
        for size in PetSize.allCases {
            runtime.setSize(size)
            waitUntil("\(size) size", timeout: 8) {
                panel.frame.size == PetGeometry.windowSize(for: size, keyCat: true)
            }
            XCTAssertEqual(settings.size, size)
        }
        KeyCatBridge.shared.handleInput(.mouseDown(isRight: false))
        XCTAssertEqual(evaluate("cat.state.mouseDown", in: webView) as? Bool, true)
        settings.paused = true
        waitUntil("paused input reset") { self.evaluate("cat.state.mouseDown", in: webView) as? Bool == false }
        XCTAssertTrue(runtime.isOpen)
        XCTAssertFalse(runtime.isInputActive)
        settings.paused = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        KeyCatBridge.shared.handleInput(.mouseDown(isRight: true))
        XCTAssertEqual(evaluate("cat.state.mouseDown", in: webView) as? Bool, true)
        runtime.handleInputTapDisabled()
        XCTAssertEqual(evaluate("cat.state.mouseDown", in: webView) as? Bool, false)
        runtime.hide()
        XCTAssertFalse(runtime.isOpen)
        XCTAssertFalse(runtime.isInputActive)
        runtime.shutdown()
        waitUntil("KeyCat detached") { !KeyCatBridge.shared.isAttached }
        let restored = PetSettings(defaults: defaults)
        XCTAssertEqual(restored.kind, .keyCat)
        XCTAssertEqual(restored.size, .large)
        let reopened = PetRuntime(settings: restored)
        defer { reopened.shutdown() }
        reopened.start()
        reopened.show()
        waitUntil("KeyCat reopened") { reopened.isOpen && KeyCatBridge.shared.isAttached }
    }

    func testSwitchesLiveWindowAndRestoresBongo() {
        _ = NSApplication.shared
        let suite = "pet-switch-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PetSettings(defaults: defaults)
        settings.kind = .bongoCat
        let runtime = PetRuntime(settings: settings)
        defer { runtime.shutdown() }
        runtime.start()
        runtime.show()
        waitUntil("pet panel") { NSApplication.shared.windows.contains { $0 is PetPanel && $0.isVisible } }
        guard let panel = NSApplication.shared.windows.first(where: { $0 is PetPanel && $0.isVisible }),
              let content = panel.contentView else { return XCTFail("pet panel missing") }
        waitUntil("BongoCat view") { self.webViews(in: content).contains { $0.url?.scheme == "petl2d" } }
        settings.kind = .keyCat
        waitUntil("KeyCat view") { self.webViews(in: content).contains { $0.url?.lastPathComponent == "index.html" } }
        waitUntil("KeyCat window size") {
            panel.frame.size == PetGeometry.windowSize(for: settings.size, keyCat: true)
        }
        XCTAssertEqual(PetSettings(defaults: defaults).kind, .keyCat)
        XCTAssertTrue(KeyCatBridge.shared.isAttached)
        settings.kind = .bongoCat
        waitUntil("BongoCat view restored") { self.webViews(in: content).contains { $0.url?.scheme == "petl2d" } }
        waitUntil("BongoCat window size") {
            panel.frame.size == PetGeometry.windowSize(for: settings.size, bongoCat: true)
        }
        XCTAssertEqual(PetSettings(defaults: defaults).kind, .bongoCat)
        waitUntil("KeyCat resources released") { !KeyCatBridge.shared.isAttached }
    }
}
