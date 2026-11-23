import CryptoKit
import XCTest
@testable import MacAppControlDeck

final class QWeatherTests: XCTestCase {
    // MARK: - JWT

    func testJWTHeaderPayloadAndSignature() throws {
        let key = Curve25519.Signing.PrivateKey()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let jwt = try QWeatherAuth.makeJWT(issuer: "Q123456789",
                                           projectID: "project-1",
                                           keyID: "kid-1",
                                           privateKey: key,
                                           now: now)
        let parts = jwt.split(separator: ".")
        XCTAssertEqual(parts.count, 3)

        let header = try XCTUnwrap(decodeBase64URL(String(parts[0])))
        XCTAssertEqual(header["alg"] as? String, "EdDSA")
        XCTAssertEqual(header["kid"] as? String, "kid-1")

        let payload = try XCTUnwrap(decodeBase64URL(String(parts[1])))
        XCTAssertEqual(payload["iss"] as? String, "Q123456789")
        XCTAssertEqual(payload["sub"] as? String, "project-1")
        let issuedAt = try XCTUnwrap(payload["iat"] as? Int)
        let expiresAt = try XCTUnwrap(payload["exp"] as? Int)
        XCTAssertEqual(issuedAt, 1_699_999_970)
        XCTAssertEqual(expiresAt - issuedAt, 86_400)

        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        let signature = try XCTUnwrap(decodeDataBase64URL(String(parts[2])))
        XCTAssertTrue(key.publicKey.isValidSignature(signature, for: signingInput))
    }

    func testPublicKeyPEMUsesSPKIPrefix() throws {
        let key = Curve25519.Signing.PrivateKey()
        let pem = QWeatherAuth.publicKeyPEM(for: key)
        XCTAssertTrue(pem.hasPrefix("-----BEGIN PUBLIC KEY-----\n"))
        XCTAssertTrue(pem.hasSuffix("\n-----END PUBLIC KEY-----"))

        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        XCTAssertEqual([UInt8](der.prefix(12)),
                       [0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00])
        XCTAssertEqual(der.suffix(32), key.publicKey.rawRepresentation)
    }

    // MARK: - 解析

    func testParseCurrentV1Shape() throws {
        let root: [String: Any] = [
            "temperature": ["value": 23, "unit": "celsius"],
            "condition": ["text": "多云", "icon": "101"],
            "feelsLike": ["value": 22],
            "humidity": 0.54
        ]
        let now = try XCTUnwrap(WeatherParsing.parseNow(root: root))
        XCTAssertEqual(now.temp, 23)
        XCTAssertEqual(now.text, "多云")
        XCTAssertEqual(now.icon, "101")
        XCTAssertEqual(now.feelsLike, 22)
        XCTAssertEqual(now.humidity, 54)
    }

    func testParseCurrentLegacyFallback() throws {
        let root: [String: Any] = [
            "now": ["temp": "8", "text": "小雨", "humidity": "92"]
        ]
        let now = try XCTUnwrap(WeatherParsing.parseNow(root: root))
        XCTAssertEqual(now.temp, 8)
        XCTAssertEqual(now.text, "小雨")
        XCTAssertEqual(now.humidity, 92)
    }

    func testParseDailyV1Shape() throws {
        let root: [String: Any] = [
            "daily": [
                [
                    "forecastStartTime": "2026-11-24T12:00Z",
                    "temperature": ["max": ["value": 25], "min": ["value": 17]],
                    "day": [
                        "condition": ["text": "晴", "icon": "100"],
                        "precipitation": ["probability": 0.1]
                    ]
                ],
                [
                    "forecastStartTime": "2026-11-25T12:00Z",
                    "temperature": ["max": ["value": 23], "min": ["value": 16]],
                    "day": [
                        "condition": ["text": "小雨", "icon": "305"],
                        "precipitation": ["probability": 0.6]
                    ]
                ]
            ]
        ]
        let days = WeatherParsing.parseDaily(root: root)
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].date, "2026-11-24")
        XCTAssertEqual(days[0].max, 25)
        XCTAssertEqual(days[0].min, 17)
        XCTAssertEqual(days[0].text, "晴")
        XCTAssertEqual(days[0].icon, "100")
        XCTAssertEqual(days[0].precipProbability, 10)
        XCTAssertEqual(days[1].precipProbability, 60)
    }

    func testParseDailyActualV1Shape() throws {
        let root: [String: Any] = [
            "days": [
                [
                    "forecastStartTime": "2026-11-23T16:00Z",
                    "temperatureMax": ["value": 7, "unit": "celsius"],
                    "temperatureMin": ["value": -2, "unit": "celsius"],
                    "daytime": [
                        "condition": ["text": "晴", "code": "100"],
                        "precipitation": ["probability": 0.2]
                    ]
                ]
            ]
        ]
        let days = WeatherParsing.parseDaily(root: root)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].max, 7)
        XCTAssertEqual(days[0].min, -2)
        XCTAssertEqual(days[0].text, "晴")
        XCTAssertEqual(days[0].icon, "100")
        XCTAssertEqual(days[0].precipProbability, 20)
    }

    func testParseDailyLegacyFields() throws {
        let root: [String: Any] = [
            "daily": [
                ["fxDate": "2026-11-26", "tempMax": 21, "tempMin": 15, "textDay": "阴", "iconDay": "104", "pop": 30]
            ]
        ]
        let days = WeatherParsing.parseDaily(root: root)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].date, "2026-11-26")
        XCTAssertEqual(days[0].max, 21)
        XCTAssertEqual(days[0].min, 15)
        XCTAssertEqual(days[0].text, "阴")
        XCTAssertEqual(days[0].precipProbability, 30)
    }

    func testParseCities() throws {
        let root: [String: Any] = [
            "location": [
                ["id": "101010100", "name": "北京", "lat": "39.90", "lon": "116.41",
                 "adm1": "北京市", "adm2": "北京"],
                ["id": "101020100", "name": "上海", "lat": 31.23, "lon": 121.47,
                 "adm1": "上海市", "adm2": "上海"]
            ]
        ]
        let cities = WeatherParsing.parseCities(root: root)
        XCTAssertEqual(cities.count, 2)
        XCTAssertEqual(cities[0].name, "北京")
        XCTAssertEqual(cities[0].latitude, 39.90)
        XCTAssertEqual(cities[0].displayName, "北京市 · 北京")
        XCTAssertEqual(cities[1].latitude, 31.23)
    }

    // MARK: - 认证模式

    func testConfigRequiresModeSpecificCredentials() {
        let base = WeatherConfig(enabled: true,
                                 host: "abc.qweatherapi.com",
                                 authMode: .apiKey,
                                 issuer: "",
                                 projectID: "",
                                 keyID: "",
                                 cityName: "北京",
                                 latitude: 39.9,
                                 longitude: 116.41,
                                 hasAPIKey: false,
                                 hasPrivateKey: false)
        XCTAssertFalse(base.canAuthenticate)

        var withKey = base
        withKey.hasAPIKey = true
        XCTAssertTrue(withKey.canAuthenticate)
        XCTAssertTrue(withKey.isConfigured)

        var jwt = base
        jwt.authMode = .jwt
        jwt.hasPrivateKey = true
        jwt.issuer = "Q123456789"
        jwt.projectID = "project"
        jwt.keyID = "kid"
        XCTAssertTrue(jwt.canAuthenticate)
        XCTAssertNotEqual(jwt.cacheKey, withKey.cacheKey)

        jwt.keyID = ""
        XCTAssertFalse(jwt.canAuthenticate)
    }

    func testAPIKeyModeDoesNotRequireJWTFields() {
        let config = WeatherConfig(enabled: true,
                                   host: "https://abc.qweatherapi.com/",
                                   authMode: .apiKey,
                                   issuer: "",
                                   projectID: "",
                                   keyID: "",
                                   cityName: "上海",
                                   latitude: 31.23,
                                   longitude: 121.47,
                                   hasAPIKey: true,
                                   hasPrivateKey: false)
        XCTAssertEqual(config.normalizedHost, "abc.qweatherapi.com")
        XCTAssertTrue(config.isConfigured)
    }

    func testSampleHostIsRejectedBeforeRequest() {
        let config = WeatherConfig(enabled: true,
                                   host: "h2a9cf3mhs.xy.qweatherapi.com",
                                   authMode: .apiKey,
                                   issuer: "",
                                   projectID: "",
                                   keyID: "",
                                   cityName: "北京",
                                   latitude: 39.9,
                                   longitude: 116.4,
                                   hasAPIKey: true,
                                   hasPrivateKey: false)
        XCTAssertNotNil(config.hostValidationMessage)
        XCTAssertFalse(config.canAuthenticate)
        XCTAssertFalse(config.isConfigured)
    }

    func testDNSFailureMessageIsActionable() {
        let message = WeatherService.friendlyMessage(URLError(.cannotFindHost))
        XCTAssertTrue(message.contains("API Host"))
        XCTAssertTrue(message.contains("专属"))
    }

    // MARK: - 路由

    func testWeatherRouteIsPublicAndReturnsJSON() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-weather-\(UUID().uuidString)")
        let router = APIRouter(store: ConfigStore(directory: directory),
                               pairing: PairingManager(),
                               activator: FakeAppControl())
        let response = await router.handle(HTTPRequest(method: "GET",
                                                       path: "/api/weather",
                                                       headers: ["Host": "127.0.0.1"],
                                                       body: Data()))
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.headers["Cache-Control"], "no-store, must-revalidate")
        let body = String(data: response.body, encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("\"ok\""))
        XCTAssertFalse(body.contains("Authorization"))
        XCTAssertFalse(body.contains("latitude"))
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - 工具

    private func decodeDataBase64URL(_ string: String) -> Data? {
        var value = string.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 { value.append("=") }
        return Data(base64Encoded: value)
    }

    private func decodeBase64URL(_ string: String) -> [String: Any]? {
        guard let data = decodeDataBase64URL(string),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }
    func testParseHourly() {
        let root: [String: Any] = [
            "hours": [
                ["forecastTime": "2026-11-23T12:00Z",
                 "condition": ["text": "多云", "code": "101"],
                 "temperature": ["value": 6.2, "unit": "°C"]],
                ["forecastTime": "2026-11-23T10:00Z",
                 "condition": ["text": "晴", "code": "100"],
                 "temperature": ["value": 3.02, "unit": "°C"]]
            ]
        ]
        let hours = WeatherParsing.parseHourly(root: root)
        XCTAssertEqual(hours.count, 2)
        XCTAssertEqual(hours[0].time, "2026-11-23T10:00Z")
        XCTAssertEqual(hours[0].temp, 3)
        XCTAssertEqual(hours[0].icon, "100")
        XCTAssertEqual(hours[0].text, "晴")
        XCTAssertEqual(hours[1].temp, 6)
        XCTAssertEqual(hours[1].icon, "101")
    }

}
