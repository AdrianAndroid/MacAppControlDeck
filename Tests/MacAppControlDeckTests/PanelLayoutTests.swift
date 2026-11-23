import AppKit
import WebKit
import XCTest
@testable import MacAppControlDeck

/// 在真实 WebKit 页面中验证布局与交互；不连接或控制真实设备。
@MainActor
final class PanelLayoutTests: XCTestCase {
    private var window: NSWindow!
    private var webView: WKWebView!

    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 320),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let buttonsScript: String
        if let path = ProcessInfo.processInfo.environment["DECK_PANEL_FIXTURE_JSON"],
           let json = try? String(contentsOfFile: path, encoding: .utf8) {
            buttonsScript = "const buttons=" + json + ".buttons;"
        } else {
            buttonsScript = #"""
            const names=['截图（区域）','Esc','桌面左','桌面右','打开 UI 草图','显示桌面','打开万年历','调度中心','打开桌面宠物','长名称快捷操作按钮'];
            const buttons=names.map((name,i)=>({id:'test-'+i,kind:'shortcut',symbol:i===0?'⌘⇧X':'⌃→',name}));
            buttons.unshift(...['Kim','ChatGPT','Google Chrome','DevEco Studio'].map((name,i)=>({id:'app-'+i,kind:'app',name,installed:true})));
            """#
        }
        let fixture = #"""
        localStorage.setItem('deck_token', 'fixture-token');
        """# + buttonsScript + #"""
        window.fetch=async (url)=>{
          if(String(url).includes('/api/buttons')) return new Response(JSON.stringify({buttons}),{status:200});
          if(String(url).includes('/api/panel-version')) return new Response(JSON.stringify({version:document.querySelector('meta[name="panel-version"]').content}),{status:200});
          if(String(url).includes('/api/activate')) return await new Promise(resolve=>{window.__finishAction=()=>resolve(new Response(JSON.stringify({status:'sent'}),{status:200}));});
          return new Response('{}',{status:200});
        };
        let fs=false;
        Object.defineProperty(document,'fullscreenElement',{configurable:true,get:()=>fs?document.documentElement:null});
        Object.defineProperty(document,'fullscreenEnabled',{configurable:true,value:true});
        document.documentElement.requestFullscreen=async()=>{fs=true;document.dispatchEvent(new Event('fullscreenchange'));};
        document.exitFullscreen=async()=>{fs=false;document.dispatchEvent(new Event('fullscreenchange'));};
        """#
        config.userContentController.addUserScript(WKUserScript(source: fixture, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        window.orderFrontRegardless()
        if let path = ProcessInfo.processInfo.environment["DECK_PANEL_TEST_EXPORT"] {
            try? PanelHTML.content.write(toFile: path, atomically: true, encoding: .utf8)
        }
        webView.loadHTMLString(PanelHTML.content, baseURL: URL(string: "https://deck.test/panel/")!)
    }

    override func tearDown() {
        webView.stopLoading()
        window.close()
        webView = nil
        window = nil
        super.tearDown()
    }

    private func js(_ expression: String, file: StaticString = #filePath, line: UInt = #line) -> Any? {
        let done = expectation(description: "JS")
        var value: Any?
        webView.evaluateJavaScript(expression) { result, error in
            if let error { XCTFail("JavaScript error: \(error)", file: file, line: line) }
            value = result
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return value
    }

    private func waitFor(_ label: String, _ check: () -> Bool) {
        let limit = Date().addingTimeInterval(8)
        while Date() < limit {
            if check() { return }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("Timed out: \(label)")
    }

    private func snapshot(_ name: String, width: CGFloat? = nil) {
        guard let dir = ProcessInfo.processInfo.environment["DECK_PANEL_SNAPSHOT_DIR"] else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let done = expectation(description: "snapshot")
        let config = WKSnapshotConfiguration()
        if let width { config.snapshotWidth = NSNumber(value: Double(width)) }
        webView.takeSnapshot(with: config) { image, _ in
            if let image,
               let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name + ".png"))
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 20)
    }

    private func assertShortcutContentFits(file: StaticString = #filePath, line: UInt = #line) {
        let result = js(#"""
        (()=>{
          const cards=[...document.querySelectorAll('#shortcutPages .btn:not(.placeholder)')];
          return cards.map(card=>{
            const b=card.getBoundingClientRect(), cs=getComputedStyle(card);
            const t=b.top+parseFloat(cs.borderTopWidth)+parseFloat(cs.paddingTop);
            const d=b.bottom-parseFloat(cs.borderBottomWidth)-parseFloat(cs.paddingBottom);
            const l=b.left+parseFloat(cs.borderLeftWidth)+parseFloat(cs.paddingLeft);
            const r=b.right-parseFloat(cs.borderRightWidth)-parseFloat(cs.paddingRight);
            const bad=[...card.children].filter(e=>getComputedStyle(e).display!=='none').filter(e=>{
              const x=e.getBoundingClientRect();
              return x.top<t-.7||x.bottom>d+.7||x.left<l-.7||x.right>r+.7||e.scrollWidth>e.clientWidth+1||e.scrollHeight>e.clientHeight+1;
            }).map(e=>e.className);
            return {name:card.querySelector('.label').textContent,bad, font:getComputedStyle(card.querySelector('.label')).fontSize};
          });
        })()
        """#, file: file, line: line) as? [[String: Any]] ?? []
        XCTAssertEqual(result.count, 10, file: file, line: line)
        for item in result {
            XCTAssertEqual((item["bad"] as? [String]) ?? ["unknown"], [], "裁切: \(item)", file: file, line: line)
        }
        XCTAssertEqual(Set(result.compactMap { $0["font"] as? String }).count, 1, "快捷按钮应使用一致字号", file: file, line: line)
    }

    func testResponsiveShortcutsAndFullscreenFallback() {
        waitFor("fixture") { (self.js("document.querySelectorAll('#shortcutPages .btn:not(.placeholder)').length") as? Int) == 10 }
        for size in [NSSize(width: 850, height: 320), NSSize(width: 976, height: 375), NSSize(width: 390, height: 844)] {
            window.setContentSize(size)
            RunLoop.main.run(until: Date().addingTimeInterval(0.45))
            _ = js("layoutNow()")
            assertShortcutContentFits()
        }
        _ = js("document.querySelector('#shortcutPages').scrollLeft = document.querySelector('#shortcutPages').clientWidth")
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        window.setContentSize(NSSize(width: 850, height: 320))
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        waitFor("retain shortcut page after rotation") {
            (self.js("Math.round(document.querySelector('#shortcutPages').scrollLeft / document.querySelector('#shortcutPages').clientWidth)") as? Int) == 1
        }
        _ = js("document.querySelector('#shortcutPages').scrollLeft=0; document.querySelector('#shortcutPages .btn').click()")
        waitFor("running action") { (self.js("document.querySelector('#shortcutPages .state').textContent") as? String)?.contains("发送") == true }
        assertShortcutContentFits()
        _ = js("window.__finishAction()")
        waitFor("action finished") { (self.js("document.querySelector('#shortcutPages .state').textContent") as? String) == "已发送" }
        assertShortcutContentFits()
        _ = js("document.querySelector('#fullscreen').click()")
        waitFor("fullscreen enter") { self.js("!!document.fullscreenElement") as? Bool == true }
        XCTAssertEqual(js("document.querySelector('#fullscreen').getAttribute('aria-label')") as? String, "退出全屏")
        _ = js("document.querySelector('#fullscreen').click()")
        waitFor("fullscreen exit") { self.js("!!document.fullscreenElement") as? Bool == false }
        _ = js("Object.defineProperty(document,'fullscreenEnabled',{configurable:true,value:false}); document.querySelector('#fullscreen').click()")
        waitFor("fullscreen fallback") { (self.js("document.querySelector('#toast').textContent") as? String)?.contains("浏览器") == true }
    }

    func testLandscapeRailNarrowAndSnapshots() {
        waitFor("fixture") { (self.js("document.querySelectorAll('#shortcutPages .btn:not(.placeholder)').length") as? Int) == 10 }
        let cases: [(String, NSSize)] = [
            ("panel-landscape", NSSize(width: 844, height: 390)),
            ("panel-narrow", NSSize(width: 480, height: 320)),
            ("panel-portrait", NSSize(width: 500, height: 900))
        ]
        for (name, size) in cases {
            window.setContentSize(size)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            _ = js("layoutNow()")
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            let fits = js("""
            (()=>{const h=document.querySelector('header');
              return h.scrollHeight<=h.clientHeight+1 && document.body.scrollHeight<=innerHeight+1 && document.body.scrollWidth<=innerWidth+1;})()
            """) as? Bool
            XCTAssertEqual(fits, true, "页面溢出: \(name)")
            if name == "panel-narrow" {
                let rail = js("getComputedStyle(document.documentElement).getPropertyValue('--left-rail').trim()") as? String
                XCTAssertEqual(rail, "70px", "窄横屏左轨应收窄到 70px")
            }
            assertShortcutContentFits()
            snapshot(name)
        }
    }

    func testRealFixtureSnapshots() {
        guard ProcessInfo.processInfo.environment["DECK_PANEL_FIXTURE_JSON"] != nil else { return }
        waitFor("real fixture") {
            (self.js("document.querySelectorAll('#appsPages .btn:not(.placeholder)').length") as? Int ?? 0) > 0
        }
        let cases: [(String, NSSize)] = [
            ("real-landscape", NSSize(width: 844, height: 390)),
            ("real-portrait", NSSize(width: 500, height: 900))
        ]
        for (name, size) in cases {
            window.setContentSize(size)
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            _ = js("layoutNow()")
            RunLoop.main.run(until: Date().addingTimeInterval(0.6))
            let fits = js("document.body.scrollHeight<=innerHeight+1 && document.body.scrollWidth<=innerWidth+1") as? Bool
            XCTAssertEqual(fits, true, "页面溢出: \(name)")
            snapshot(name, width: size.width)
        }
    }
}
