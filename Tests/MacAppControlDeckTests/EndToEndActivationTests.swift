import XCTest
import AppKit
@testable import MacAppControlDeck

final class EndToEndActivationTests: XCTestCase {
    private let calculatorID = "com.apple.Calculator"
    private let calculatorPath = "/System/Applications/Calculator.app"

    private var directory: URL!
    private var server: DeckHTTPServer!
    private var store: ConfigStore!
    private var pairing: PairingManager!
    private var baseURL: URL!
    private var button: ButtonConfig!
    private var token: String!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-e2e-\(UUID().uuidString)")
        store = ConfigStore(directory: directory)
        pairing = PairingManager()
        button = store.addButton(name: "计算器", bundleID: calculatorID, appPath: calculatorPath)
        server = DeckHTTPServer(router: APIRouter(store: store,
                                                  pairing: pairing,
                                                  activator: AppControl(logDirectory: directory.appendingPathComponent("logs"))))
        let status = server.start(preferredPort: 47888)
        XCTAssertTrue(status.running, "真实服务器必须启动")
        baseURL = URL(string: "http://127.0.0.1:\(status.port)")!
        token = try await pair()
        try await terminateCalculator()
    }

    override func tearDown() async throws {
        server?.stop()
        try await terminateCalculator()
        try? FileManager.default.removeItem(at: directory)
    }

    private func terminateCalculator() async throws {
        for app in NSWorkspace.shared.runningApplications
        where AppControl.isBundle(app.bundleIdentifier, calculatorID) {
            app.terminate()
        }
        for _ in 0..<20 {
            if AppControl.runningApp(calculatorID) == nil { return }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    private func pair() async throws -> String {
        let code = pairing.newCode()
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pair"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["code": code, "deviceName": "e2e-iphone"])
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        struct R: Decodable { let token: String }
        return try JSONDecoder().decode(R.self, from: data).token
    }

    private func activate() async throws -> (Int, [String: String]) {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/activate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["buttonId": button.id])
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] ?? [:]
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, json)
    }

    private func waitForFrontmost(_ bundleID: String, timeout: TimeInterval = 6) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        var front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        while Date() < deadline {
            front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if AppControl.isBundle(front, bundleID) { return front }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return front
    }

    func test_unknownButtonNeverLaunchesAnything() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/activate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["buttonId": "not-a-button"])
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 404)
        XCTAssertNil(AppControl.runningApp(calculatorID), "未知按钮不得启动任何应用")
    }

    func test_buttonsEndpointReturnsConfiguredButton() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/buttons"))
        request.setValue("Bearer \(token!)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("计算器"))
        XCTAssertTrue(text.contains(button.id))
    }

    func test_pairThenLaunchAndActivateCalculator() async throws {
        guard FileManager.default.fileExists(atPath: calculatorPath) else {
            throw XCTSkip("本机没有计算器应用，跳过真实激活测试")
        }
        XCTAssertNil(AppControl.runningApp(calculatorID), "前置条件：计算器未运行")

        let first = try await activate()
        XCTAssertEqual(first.0, 200)
        XCTAssertEqual(first.1["status"], "launched", "首次点击应启动应用: \(first.1)")

        let frontAfterLaunch = await waitForFrontmost(calculatorID)
        XCTAssertTrue(AppControl.isBundle(frontAfterLaunch, calculatorID),
                      "启动后计算器应成为前台，实际: \(frontAfterLaunch ?? "nil")")

        let second = try await activate()
        XCTAssertEqual(second.0, 200)
        XCTAssertNotEqual(second.1["status"], "launched", "已运行的应用不应报告为‘已启动’")
        XCTAssertTrue(["activated", "unconfirmed"].contains(second.1["status"] ?? ""),
                      "已运行应用应走激活路径: \(second.1)")
    }

    func test_selectedAppActivatesWhenAlreadyRunning() async throws {
        guard FileManager.default.fileExists(atPath: calculatorPath) else {
            throw XCTSkip("本机没有计算器应用，跳过真实激活测试")
        }
        _ = try await activate()
        try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertNotNil(AppControl.runningApp(calculatorID), "第一次激活后应用应在运行")

        let second = try await activate()
        XCTAssertEqual(second.0, 200)
        XCTAssertNotEqual(second.1["status"], "launched")
    }
}
