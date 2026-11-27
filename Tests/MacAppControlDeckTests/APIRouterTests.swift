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
        let router = makeRouter()
        let entry = await router.handle(makeRequest("GET", "/panel/"))
        XCTAssertEqual(entry.status, 302, "面板入口应带版本参数跳转，避免缓存旧页面")
        guard let location = entry.headers["Location"] else {
            return XCTFail("缺少 Location 跳转地址")
        }
        let response = await router.handle(makeRequest("GET", location))
        XCTAssertEqual(response.status, 200)
        let html = String(data: response.body, encoding: .utf8)!
        XCTAssertTrue(html.contains("Mac 应用快捷控制台"))
        XCTAssertTrue(html.contains("grid-template-columns: var(--left-rail)"), "横屏需要左侧竖轨")
        XCTAssertTrue(html.contains("class=\"zone-head\""), "应用/快捷标题与翻页圆点横排在区域顶部")
        XCTAssertTrue(html.contains("12/appCols"), "横屏每页固定 12 个应用")
        XCTAssertTrue(html.contains("pcount"), "分页需要页码")
    }

    func test_screenCountdownServedWithoutToken() async {
        let router = makeRouter()
        let response = await router.handle(makeRequest("GET", "/api/screen/countdown"))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")
        let json = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any]
        XCTAssertNotNil(json?["enabled"], "需要 enabled 开关")
        XCTAssertNotNil(json?["phase"], "需要阶段")
        XCTAssertNotNil(json?["targetEpoch"], "需要目标时间点，页面只做倒数")
        XCTAssertNotNil(json?["label"])
        XCTAssertNotNil(json?["showSeconds"])
    }

    func test_screenServedWithoutToken() async {
        let router = makeRouter()
        let entry = await router.handle(makeRequest("GET", "/screen/"))
        XCTAssertEqual(entry.status, 302, "副屏入口应带版本参数跳转，避免缓存旧页面")
        guard let location = entry.headers["Location"] else {
            return XCTFail("缺少 Location 跳转地址")
        }
        XCTAssertTrue(location.hasPrefix("/screen/?v="))

        let response = await router.handle(makeRequest("GET", location))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")
        let html = String(data: response.body, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("副屏 · 时钟与月历"))
        XCTAssertFalse(html.contains("deck_token"), "只读副屏不能携带配对凭证")
        XCTAssertFalse(html.contains("/api/activate"), "副屏不应触发控制动作")
        XCTAssertFalse(html.contains("Authorization"))
        XCTAssertTrue(html.contains("/api/weather"), "副屏需要拉取只读天气")
        XCTAssertTrue(html.contains("/api/time"), "副屏需要与 Mac 时间对齐")
        XCTAssertTrue(html.contains("id=\"refresh\""), "副屏需要手动刷新入口")
        XCTAssertTrue(html.contains("/api/screen/events"), "副屏需要事件长轮询")
        XCTAssertTrue(html.contains("grid-template-columns: repeat(3, minmax(0, 1fr))"), "横屏三栏严格等宽")
        XCTAssertTrue(html.contains("class=\"col clock-col\""), "时钟列")
        XCTAssertTrue(html.contains("class=\"col cal-col\""), "月历列")
        XCTAssertTrue(html.contains("class=\"col wx-col\""), "天气列")
        XCTAssertTrue(html.contains("WEATHER FORECAST"), "天气栏需要预报表头")
        XCTAssertTrue(html.contains("data.daily.slice(0, 5)"), "预报展示 5 天")
        XCTAssertTrue(html.contains("wx-day .i"), "预报行需要天气图标")
        XCTAssertTrue(html.contains("wx-hours"), "副屏需要小时预报条")
        XCTAssertTrue(html.contains("hours.slice(0, 4)"), "小时条展示现在 + 4 小时")
    }

    func test_screenEventRouteReturnsRevision() async {
        let router = makeRouter()
        await ScreenEventHub.shared.publish()
        let response = await router.handle(makeRequest("GET", "/api/screen/events?since=0"))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")
        struct Event: Decodable { let revision: Int }
        let event = try? JSONDecoder().decode(Event.self, from: response.body)
        XCTAssertNotNil(event)
        XCTAssertGreaterThanOrEqual(event?.revision ?? 0, 1)
    }

    func test_timeRouteReturnsMacClock() async {
        let before = Date().timeIntervalSince1970
        let router = makeRouter()
        let response = await router.handle(makeRequest("GET", "/api/time"))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")

        struct Clock: Decodable {
            let epoch: Double
            let offsetMinutes: Int
            let year: Int
            let month: Int
            let day: Int
            let hour: Int
            let minute: Int
            let second: Int
            let timeZone: String
            let iso: String
            let screenVersion: String
        }
        let clock = try? JSONDecoder().decode(Clock.self, from: response.body)
        let value = try? XCTUnwrap(clock)
        let after = Date().timeIntervalSince1970
        XCTAssertNotNil(value)
        guard let clock = value else { return }
        XCTAssertGreaterThanOrEqual(clock.epoch, before - 1)
        XCTAssertLessThanOrEqual(clock.epoch, after + 1)
        XCTAssertTrue((1...12).contains(clock.month))
        XCTAssertTrue((1...31).contains(clock.day))
        XCTAssertTrue(clock.iso.contains("T"))
        XCTAssertFalse(clock.timeZone.isEmpty)
        XCTAssertFalse(clock.screenVersion.isEmpty)

        let body = String(data: response.body, encoding: .utf8) ?? ""
        XCTAssertFalse(body.contains("latitude"))
        XCTAssertFalse(body.contains("deck_token"))
    }

    func testScreenDisplayIsPublicAndReturnsConfig() async {
        let response = await makeRouter().handle(makeRequest("GET", "/api/screen/display"))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")
        struct Display: Decodable {
            let size: String
            let petMode: String
            let petId: String
            let petInterval: Int
            let keepAwake: Bool
            let petSwitchNonce: Int
        }
        let display = try? JSONDecoder().decode(Display.self, from: response.body)
        let value = try? XCTUnwrap(display)
        guard let display = value else { return }
        XCTAssertTrue(ScreenDisplayConfig.validSizes.contains(display.size))
        XCTAssertTrue(["fixed", "random"].contains(display.petMode))
        XCTAssertTrue(ScreenDisplayConfig.validPetIDs.contains(display.petId))
        XCTAssertTrue(ScreenDisplayConfig.validIntervals.contains(display.petInterval))
    }

    func testScreenPresenceRegistersReadOnlyClient() async {
        let store = ConfigStore(directory: directory)
        let router = makeRouter(store: store)
        let body = try! JSONEncoder().encode(["id": "screen-test-1234"])
        let response = await router.handle(makeRequest(
            "POST", "/api/screen/presence",
            headers: ["Host": "127.0.0.1", "User-Agent": "Mozilla/5.0 (iPhone) Version/17.0 Safari/605.1"],
            body: body))
        XCTAssertEqual(response.status, 204)
        let clients = store.screenClientSnapshot()
        XCTAssertEqual(clients.count, 1)
        XCTAssertEqual(clients.first?.id, "screen-test-1234")
        XCTAssertEqual(clients.first?.name, "iPhone · Safari")
    }

    func testScreenPresenceRejectsInvalidID() async {
        let router = makeRouter()
        let body = try! JSONEncoder().encode(["id": "../bad"])
        let response = await router.handle(makeRequest("POST", "/api/screen/presence", body: body))
        XCTAssertEqual(response.status, 400)
    }
}
