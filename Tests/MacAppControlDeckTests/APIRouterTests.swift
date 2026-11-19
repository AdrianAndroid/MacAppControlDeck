import XCTest
@testable import MacAppControlDeck

final class FakeAppControl: AppControlling {
    var lastBundleID: String?
    var outcome: AppActivationOutcome

    init(outcome: AppActivationOutcome = AppActivationOutcome(status: .activated, message: "已切换到前台")) {
        self.outcome = outcome
    }

    func activate(bundleID: String) async -> AppActivationOutcome {
        lastBundleID = bundleID
        return outcome
    }
}

final class APIRouterTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-router-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeRouter(activator: AppControlling = FakeAppControl(),
                            store: ConfigStore? = nil) -> APIRouter {
        APIRouter(store: store ?? ConfigStore(directory: directory),
                  pairing: PairingManager(),
                  activator: activator)
    }

    private func makeRequest(_ method: String, _ path: String,
                             headers: [String: String] = ["Host": "127.0.0.1"],
                             body: Data = Data(), token: String? = nil) -> HTTPRequest {
        var finalHeaders = headers
        if let token { finalHeaders["X-Device-Token"] = token }
        return HTTPRequest(method: method, path: path, headers: finalHeaders, body: body)
    }

    private func pair(router: APIRouter, code: String, name: String = "iPhone") async -> String? {
        let response = await router.handle(makeRequest("POST", "/api/pair", body: try! JSONEncoder().encode(["code": code, "deviceName": name])))
        struct T: Decodable { let token: String }
        return (try? JSONDecoder().decode(T.self, from: response.body))?.token
    }

    func test_healthIsPublic() async {
        let response = await makeRouter().handle(makeRequest("GET", "/api/health"))
        XCTAssertEqual(response.status, 200)
    }

    func test_unauthenticatedRequestsRejected() async {
        let router = makeRouter()
        let buttons = await router.handle(makeRequest("GET", "/api/buttons"))
        XCTAssertEqual(buttons.status, 401)
        let activate = await router.handle(makeRequest("POST", "/api/activate", body: Data(#"{"buttonId":"x"}"#.utf8)))
        XCTAssertEqual(activate.status, 401)
    }

    func test_wrongPairingCodeIssuesNoToken() async {
        let router = makeRouter()
        _ = router.pairing.newCode()
        let token = await pair(router: router, code: "000000")
        XCTAssertNil(token)
    }

    func test_correctPairingIssuesTokenAndButtonsAccess() async {
        let router = makeRouter()
        let code = router.pairing.newCode()
        let token = await pair(router: router, code: code)
        XCTAssertNotNil(token, "正确配对码必须能换到 token")

        let persistedStore = ConfigStore(directory: directory)
        XCTAssertEqual(persistedStore.device(token: token!)?.name, "iPhone", "配对设备应已持久化")

        let buttons = await router.handle(makeRequest("GET", "/api/buttons", token: token))
        XCTAssertEqual(buttons.status, 200)
        _ = await router.handle(makeRequest("GET", "/api/buttons"))
    }

    func test_revokedTokenRejected() async {
        let store = ConfigStore(directory: directory)
        let router = makeRouter(store: store)
        let code = router.pairing.newCode()
        let token = await pair(router: router, code: code)!
        let before = await router.handle(makeRequest("GET", "/api/buttons", token: token))
        XCTAssertEqual(before.status, 200)
        XCTAssertTrue(store.revokeDevice(token: token), "撤销已配对设备")
        let after = await router.handle(makeRequest("GET", "/api/buttons", token: token))
        XCTAssertEqual(after.status, 401, "撤销后旧凭证必须失效")
        let activate = await router.handle(makeRequest("POST", "/api/activate",
                                                       body: Data(#"{"buttonId":"x"}"#.utf8), token: token))
        XCTAssertEqual(activate.status, 401, "撤销后也不能执行任何命令")
    }

    func test_unknownButtonRejected() async {
        let fake = FakeAppControl()
        let router = makeRouter(activator: fake)
        let code = router.pairing.newCode()
        let token = await pair(router: router, code: code)!
        let response = await router.handle(makeRequest("POST", "/api/activate",
                                                       body: Data(#"{"buttonId":"nope"}"#.utf8), token: token))
        XCTAssertEqual(response.status, 404)
        XCTAssertNil(fake.lastBundleID, "按钮不存在时不得启动任何应用")
    }

    func test_badRequestBodyRejected() async {
        let router = makeRouter()
        let code = router.pairing.newCode()
        let token = await pair(router: router, code: code)!
        let response = await router.handle(makeRequest("POST", "/api/activate",
                                                       body: Data("not-even-json".utf8), token: token))
        XCTAssertEqual(response.status, 400)
    }

    func test_oversizedBodyRejected() async {
        let router = makeRouter()
        let response = await router.handle(makeRequest("POST", "/api/activate", body: Data(repeating: 0, count: 8192)))
        XCTAssertEqual(response.status, 413)
    }

    func test_spoofedHostRejected() async {
        let router = makeRouter()
        let response = await router.handle(makeRequest("GET", "/api/health", headers: ["Host": "evil.example.com"]))
        XCTAssertEqual(response.status, 403, "DNS 重绑定场景的伪造 Host 必须拒绝")
    }

    func test_unknownPathIs404() async {
        let response = await makeRouter().handle(makeRequest("GET", "/api/exec"))
        XCTAssertEqual(response.status, 404)
    }

    func test_panelServedWithoutToken() async {
        let response = await makeRouter().handle(makeRequest("GET", "/panel/"))
        XCTAssertEqual(response.status, 200)
        XCTAssertTrue(String(data: response.body, encoding: .utf8)!.contains("Mac 应用快捷控制台"))
    }
}
