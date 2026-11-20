import XCTest
@testable import MacAppControlDeck

final class FakeShortcutInjector: ShortcutInjecting {
    var lastCombo: ShortcutCombo?
    var result = ShortcutInjectionResult(sent: true, errorCode: nil, message: "已发送快捷键")

    func inject(_ combo: ShortcutCombo) -> ShortcutInjectionResult {
        lastCombo = combo
        return result
    }
}

final class ShortcutActionsTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-shortcut-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_presetSymbolsAndKeyCodes() {
        func preset(_ id: String) -> ShortcutPreset {
            ShortcutPresets.all.first { $0.id == id }!
        }
        XCTAssertEqual(preset("copy").symbol, "⌘C")
        XCTAssertEqual(preset("paste").symbol, "⌘V")
        XCTAssertEqual(preset("desktop-left").symbol, "⌃←")
        XCTAssertEqual(preset("desktop-right").symbol, "⌃→")
        XCTAssertEqual(preset("escape").symbol, "⎋")
        XCTAssertEqual(preset("enter").symbol, "↩")
        XCTAssertEqual(preset("f1").symbol, "F1")
        XCTAssertEqual(preset("f12").symbol, "F12")
        XCTAssertEqual(preset("copy").combo.keyCode, 8)
        XCTAssertEqual(preset("f1").combo.keyCode, 122)
        XCTAssertEqual(preset("desktop-left").combo.keyCode, 123)
        XCTAssertEqual(preset("escape").combo.keyCode, 53)
    }

    func test_spaceSwitchClassification() {
        let left = ShortcutCombo(modifiers: [.control], keyCode: 123, keyLabel: "←")
        let right = ShortcutCombo(modifiers: [.control], keyCode: 124, keyLabel: "→")
        let copy = ShortcutCombo(modifiers: [.command], keyCode: 8, keyLabel: "C")
        XCTAssertTrue(KeyInjector.isSpaceSwitch(left))
        XCTAssertTrue(KeyInjector.isSpaceSwitch(right))
        XCTAssertFalse(KeyInjector.isSpaceSwitch(copy))
        XCTAssertFalse(KeyInjector.isSpaceSwitch(ShortcutCombo(modifiers: [.control, .shift], keyCode: 123, keyLabel: "←")))
    }

    func test_comboNormalizationDedupesAndSorts() {
        let combo = ShortcutCombo(modifiers: [.shift, .command, .shift, .control],
                                 keyCode: 40, keyLabel: "K")
        XCTAssertEqual(combo.normalized.modifiers, [.control, .shift, .command])
        XCTAssertEqual(combo.normalized.symbol, "⌃⇧⌘K")
    }

    func test_legacyConfigDecodesAsAppButton() throws {
        let json = """
        [{"id":"1","name":"Safari","bundleID":"com.apple.Safari","appPath":"/Applications/Safari.app","sortOrder":0}]
        """
        let buttons = try JSONDecoder().decode([ButtonConfig].self, from: Data(json.utf8))
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(buttons[0].kind, .app)
        XCTAssertNil(buttons[0].shortcut)
    }

    func test_shortcutConfigRoundtrip() throws {
        let original = ButtonConfig(id: "s1", kind: .shortcut, name: "复制", sortOrder: 0,
                                    shortcut: ShortcutCombo(modifiers: [.command], keyCode: 8, keyLabel: "C"))
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ButtonConfig].self, from: data)
        XCTAssertEqual(decoded[0].kind, .shortcut)
        XCTAssertEqual(decoded[0].displaySymbol, "⌘C")
    }

    func test_storeGroupsSortAndPersistsShortcuts() {
        let store = ConfigStore(directory: directory)
        _ = store.addButton(name: "Safari", bundleID: "com.apple.Safari", appPath: "/Applications/Safari.app")
        let copy = store.addShortcutButton(name: "复制",
                                           combo: ShortcutCombo(modifiers: [.command], keyCode: 8, keyLabel: "C"))
        let paste = store.addShortcutButton(name: "粘贴",
                                            combo: ShortcutCombo(modifiers: [.command], keyCode: 9, keyLabel: "V"))
        XCTAssertEqual(store.buttons(kind: .app).count, 1)
        XCTAssertEqual(store.buttons(kind: .shortcut).count, 2)

        XCTAssertTrue(store.moveButton(id: paste.id, offset: -1))
        XCTAssertEqual(store.buttons(kind: .shortcut).map(\.name), ["粘贴", "复制"])

        let reloaded = ConfigStore(directory: directory)
        XCTAssertEqual(reloaded.buttons(kind: .shortcut).map(\.name), ["粘贴", "复制"])
        XCTAssertEqual(reloaded.button(id: copy.id)?.displaySymbol, "⌘C")
    }

    private func makeRouter(injector: ShortcutInjecting) -> APIRouter {
        APIRouter(store: ConfigStore(directory: directory),
                  pairing: PairingManager(),
                  activator: FakeAppControl(),
                  injector: injector)
    }

    private func pairToken(_ router: APIRouter) async -> String {
        let code = router.pairing.newCode()
        let body = try! JSONEncoder().encode(["code": code, "deviceName": "test-iphone"])
        let response = await router.handle(HTTPRequest(method: "POST", path: "/api/pair",
                                                       headers: ["Host": "127.0.0.1"], body: body))
        struct T: Decodable { let token: String }
        return (try! JSONDecoder().decode(T.self, from: response.body)).token
    }

    func test_moveShortcutToIndexAndKindRanking() {
        let store = ConfigStore(directory: directory)
        let a = store.addShortcutButton(name: "A", combo: ShortcutCombo(modifiers: [.command], keyCode: 0, keyLabel: "A"))
        let b = store.addShortcutButton(name: "B", combo: ShortcutCombo(modifiers: [.command], keyCode: 1, keyLabel: "S"))
        let c = store.addCommandButton(name: "C", appPath: "/Applications/Snipaste.app",
                                       bundleID: "com.Snipaste", arguments: ["snip"])
        _ = store.addButton(name: "App", bundleID: "com.apple.Safari", appPath: "/Applications/Safari.app")

        XCTAssertTrue(store.moveButton(id: b.id, toIndex: 0))
        XCTAssertEqual(store.buttons(kind: .shortcut).map(\.name), ["B", "A"])

        let ordered = store.sortedButtons().map(\.kind)
        XCTAssertEqual(ordered, [.app, .shortcut, .shortcut, .command])

        // 命令按钮可与快捷操作在同一"快捷"组内互相移动
        XCTAssertTrue(store.moveButton(id: c.id, toIndex: 0))
        XCTAssertEqual(store.sortedButtons().map(\.name), ["App", "C", "B", "A"])
        XCTAssertTrue(store.moveButton(id: a.id, toIndex: 0))
        XCTAssertEqual(store.sortedButtons().map(\.name), ["App", "A", "C", "B"])
    }

    func test_builtinButtonRoundtripAndPayload() async {
        let json = """
        [{"id":"b1","kind":"builtin","name":"截图（区域）","sortOrder":0,"builtinAction":"capture.area"}]
        """
        let decoded = try! JSONDecoder().decode([ButtonConfig].self, from: Data(json.utf8))
        XCTAssertEqual(decoded[0].kind, .builtin)
        XCTAssertEqual(decoded[0].builtinAction, "capture.area")
        XCTAssertEqual(BuiltinActions.symbol(for: decoded[0].builtinAction), "⛶")

        let router = makeRouter(injector: FakeShortcutInjector())
        let token = await pairToken(router)
        _ = router.store.addBuiltinButton(name: "截图（区域）", action: "capture.area")
        let response = await router.handle(HTTPRequest(method: "GET", path: "/api/buttons",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "X-Device-Token": token],
                                                       body: Data()))
        let text = String(data: response.body, encoding: .utf8)!
        XCTAssertTrue(text.contains("\"kind\":\"builtin\""))
        XCTAssertTrue(text.contains("\"symbol\":\"⛶\""))
        XCTAssertEqual(router.store.buttons(kind: .builtin).count, 1)
    }

    func test_routerDispatchesShortcutToInjector() async {
        let injector = FakeShortcutInjector()
        let router = makeRouter(injector: injector)
        let token = await pairToken(router)
        let store = router.store
        let button = store.addShortcutButton(name: "复制",
                                             combo: ShortcutCombo(modifiers: [.command], keyCode: 8, keyLabel: "C"))

        let body = try! JSONEncoder().encode(["buttonId": button.id])
        let response = await router.handle(HTTPRequest(method: "POST", path: "/api/activate",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "Content-Type": "application/json",
                                                                 "X-Device-Token": token],
                                                       body: body))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(injector.lastCombo?.keyCode, 8)
        let json = try! JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        XCTAssertEqual(json["status"] as? String, "sent")
    }

    func test_routerShortcutFailureReturnsError() async {
        let injector = FakeShortcutInjector()
        injector.result = ShortcutInjectionResult(sent: false,
                                                  errorCode: "accessibility-required",
                                                  message: "需要辅助功能权限")
        let router = makeRouter(injector: injector)
        let token = await pairToken(router)
        let button = router.store.addShortcutButton(name: "F1",
                                                    combo: ShortcutCombo(modifiers: [], keyCode: 122, keyLabel: "F1"))
        let body = try! JSONEncoder().encode(["buttonId": button.id])
        let response = await router.handle(HTTPRequest(method: "POST", path: "/api/activate",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "Content-Type": "application/json",
                                                                 "X-Device-Token": token],
                                                       body: body))
        XCTAssertEqual(response.status, 403)
        let json = try! JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        XCTAssertEqual(json["error"] as? String, "accessibility-required")
    }

    func test_commandButtonRunsAppCLI() async throws {
        let appDir = directory.appendingPathComponent("FakeTool.app")
        let macos = appDir.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        let script = macos.appendingPathComponent("FakeTool")
        try "#!/bin/sh\nexit 0\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let plist = appDir.appendingPathComponent("Contents/Info.plist")
        let dict: [String: Any] = ["CFBundleExecutable": "FakeTool",
                                   "CFBundleIdentifier": "local.faketool",
                                   "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: plist)

        let router = makeRouter(injector: FakeShortcutInjector())
        let token = await pairToken(router)
        let button = router.store.addCommandButton(name: "工具",
                                                   appPath: appDir.path,
                                                   bundleID: "local.faketool",
                                                   arguments: ["run"])
        let body = try! JSONEncoder().encode(["buttonId": button.id])
        let response = await router.handle(HTTPRequest(method: "POST", path: "/api/activate",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "Content-Type": "application/json",
                                                                 "X-Device-Token": token],
                                                       body: body))
        XCTAssertEqual(response.status, 200)
        let json = try! JSONSerialization.jsonObject(with: response.body) as! [String: Any]
        XCTAssertEqual(json["status"] as? String, "sent")
    }

    func test_commandButtonAppearsInPayload() async {
        let router = makeRouter(injector: FakeShortcutInjector())
        let token = await pairToken(router)
        _ = router.store.addCommandButton(name: "截图", appPath: "/Applications/Snipaste.app",
                                          bundleID: "com.Snipaste", arguments: ["snip"])
        let response = await router.handle(HTTPRequest(method: "GET", path: "/api/buttons",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "X-Device-Token": token],
                                                       body: Data()))
        let text = String(data: response.body, encoding: .utf8)!
        XCTAssertTrue(text.contains("\"kind\":\"command\""))
    }

    func test_buttonsPayloadIncludesKindAndSymbol() async {
        let router = makeRouter(injector: FakeShortcutInjector())
        let token = await pairToken(router)
        _ = router.store.addShortcutButton(name: "Esc",
                                           combo: ShortcutCombo(modifiers: [], keyCode: 53, keyLabel: "⎋"))
        let response = await router.handle(HTTPRequest(method: "GET", path: "/api/buttons",
                                                       headers: ["Host": "127.0.0.1",
                                                                 "X-Device-Token": token],
                                                       body: Data()))
        XCTAssertEqual(response.status, 200)
        let text = String(data: response.body, encoding: .utf8)!
        XCTAssertTrue(text.contains("\"kind\":\"shortcut\""))
        XCTAssertTrue(text.contains("\"symbol\":\"⎋\""))
    }
}
