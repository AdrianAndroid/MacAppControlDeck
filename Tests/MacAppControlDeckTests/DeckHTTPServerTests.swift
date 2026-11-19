import XCTest
import Network
@testable import MacAppControlDeck

final class DeckHTTPServerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-server-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_realServerEndToEnd() async throws {
        let server = DeckHTTPServer(router: APIRouter(store: ConfigStore(directory: directory),
                                                      pairing: PairingManager(),
                                                      activator: FakeAppControl()))
        let status = server.start(preferredPort: 47999)
        XCTAssertTrue(status.running, "服务必须启动: \(status.errorText ?? "")")
        defer { server.stop() }

        let base = URL(string: "http://127.0.0.1:\(status.port)")!

        do {
            let (data, response) = try await URLSession.shared.data(from: base.appendingPathComponent("api/health"))
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("MacAppControlDeck"))
        }

        do {
            var request = URLRequest(url: base.appendingPathComponent("api/buttons"))
            let (data, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 401)
            XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("unauthorized"))
        }

        do {
            let code = FakePairingCodeProbe.code(of: routerOf(server))
            var request = URLRequest(url: base.appendingPathComponent("api/pair"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["code": code, "deviceName": "e2e"])
            let (_, response) = try await URLSession.shared.data(for: request)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        }
    }

    private func routerOf(_ server: DeckHTTPServer) -> APIRouter {
        Mirror(reflecting: server).children.first { ($0.value as? APIRouter) != nil }!.value as! APIRouter
    }
}

enum FakePairingCodeProbe {
    static func code(of router: APIRouter) -> String {
        router.pairing.newCode()
    }
}
