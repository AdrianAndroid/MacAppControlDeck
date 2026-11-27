import XCTest
@testable import MacAppControlDeck

@MainActor
final class AppDockRouterTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private var directory: URL!
    private var suite: String!
    private var defaults: UserDefaults!
    private var settings: PetDockSettings!
    private var stats: PetDockStats!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-dock-router-\(UUID().uuidString)")
        suite = "app-dock-router-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        settings = PetDockSettings(defaults: defaults, notifiesCenter: false)
        stats = PetDockStats(defaults: defaults)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        settings = nil
        stats = nil
        super.tearDown()
    }

    private func makeOrdering(provide apps: @escaping () -> [ButtonConfig], hold: TimeInterval = 5) -> AppDockOrdering {
        let fixed = base
        return AppDockOrdering(settings: settings,
                               stats: stats,
                               appsProvider: apps,
                               now: { fixed },
                               holdDuration: hold)
    }

    private func makeRouter(store: ConfigStore, ordering: AppDockOrdering) -> APIRouter {
        let token = "test-token"
        store.addDevice(token: token, name: "iPhone")
        return APIRouter(store: store,
                         pairing: PairingManager(),
                         activator: FakeAppControl(),
                         ordering: ordering)
    }

    private func request(_ method: String, _ path: String, token: String = "test-token", body: String = "") -> HTTPRequest {
        HTTPRequest(method: method,
                    path: path,
                    headers: ["Host": "127.0.0.1", "X-Device-Token": token],
                    body: Data(body.utf8))
    }

    private struct ButtonsResponse: Decodable {
        struct Button: Decodable { let id: String; let kind: String }
        let buttons: [Button]
    }

    func testButtonsFollowSharedOrder() async throws {
        let store = ConfigStore(directory: directory)
        _ = store.addButton(name: "A", bundleID: "com.a", appPath: "/Applications/A.app")
        _ = store.addButton(name: "B", bundleID: "com.b", appPath: "/Applications/B.app")
        let ordering = makeOrdering(provide: { store.sortedButtons().filter { $0.kind == .app } })
        settings.sortMode = .frequency
        stats.record(bundleID: "com.b", at: base)
        stats.record(bundleID: "com.b", at: base.addingTimeInterval(60))

        let router = makeRouter(store: store, ordering: ordering)
        let response = await router.handle(request("GET", "/api/buttons"))
        XCTAssertEqual(response.status, 200)
        let payload = try JSONDecoder().decode(ButtonsResponse.self, from: response.body)
        let b = store.sortedButtons().first { $0.bundleID == "com.b" }
        XCTAssertEqual(payload.buttons.first?.id, b?.id, "点击最多的应用应排在应用区首位")
    }

    func testActivateRecordsClickForApps() async {
        let store = ConfigStore(directory: directory)
        let a = store.addButton(name: "A", bundleID: "com.a", appPath: "/Applications/A.app")
        let ordering = makeOrdering(provide: { store.sortedButtons().filter { $0.kind == .app } })
        let router = makeRouter(store: store, ordering: ordering)

        let response = await router.handle(request("POST", "/api/activate", body: #"{"buttonId":"\#(a.id)"}"#))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(stats.events["com.a"]?.count, 1)
        XCTAssertTrue(ordering.isHoldingOrder, "点击后应冻结当前顺序")
    }

    func testOrderChangesOnlyAfterHoldExpires() async throws {
        let store = ConfigStore(directory: directory)
        _ = store.addButton(name: "A", bundleID: "com.a", appPath: "/Applications/A.app")
        _ = store.addButton(name: "B", bundleID: "com.b", appPath: "/Applications/B.app")
        let c = store.addButton(name: "C", bundleID: "com.c", appPath: "/Applications/C.app")
        let ordering = makeOrdering(provide: { store.sortedButtons().filter { $0.kind == .app } }, hold: 0.15)
        let router = makeRouter(store: store, ordering: ordering)

        let before = await router.handle(request("GET", "/api/buttons"))
        let beforePayload = try JSONDecoder().decode(ButtonsResponse.self, from: before.body)
        XCTAssertEqual(beforePayload.buttons.first?.kind, "app")

        let activated = await router.handle(request("POST", "/api/activate", body: #"{"buttonId":"\#(c.id)"}"#))
        XCTAssertEqual(activated.status, 200)

        let frozen = await router.handle(request("GET", "/api/buttons"))
        let frozenPayload = try JSONDecoder().decode(ButtonsResponse.self, from: frozen.body)
        XCTAssertEqual(frozenPayload.buttons.first?.id, beforePayload.buttons.first?.id, "5 秒内顺序不变")

        try await Task.sleep(nanoseconds: 400_000_000)

        let after = await router.handle(request("GET", "/api/buttons"))
        let afterPayload = try JSONDecoder().decode(ButtonsResponse.self, from: after.body)
        XCTAssertEqual(afterPayload.buttons.first?.id, c.id, "冻结到期后点击应用排到首位")
    }
}
