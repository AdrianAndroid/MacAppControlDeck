import CryptoKit
import Foundation

enum QWeatherAuthError: LocalizedError {
    case missingPrivateKey
    case invalidPrivateKey
    case missingAPIKey
    case keychainWriteFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .missingPrivateKey: return "还没有生成和风天气私钥"
        case .invalidPrivateKey: return "本机凭据文件里的私钥无法读取"
        case .missingAPIKey: return "还没有保存和风 API Key"
        case .keychainWriteFailed: return "无法写入 macOS 钥匙串"
        case .encodingFailed: return "JWT 编码失败"
        }
    }
}

/// 和风天气新版 JWT（EdDSA）认证。
/// 私钥只存本机 0600 凭据文件；公钥以 SPKI PEM 形式展示，供粘贴到和风控制台。
enum QWeatherAuth {
    static let service = "com.zhaojian.MacAppControlDeck.weather"
    static let account = "qweather-private-key"
    static let apiKeyAccount = "qweather-api-key"

    private static let cacheLock = NSLock()
    private static var apiKeyCache: String?
    private static var apiKeyLoaded = false
    private static var privateKeyCache: Curve25519.Signing.PrivateKey?
    private static var privateKeyLoaded = false

    private static let spkiPrefix = Data([
        0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x70, 0x03, 0x21, 0x00
    ])

    static func hasPrivateKey() -> Bool {
        (try? privateKey()) != nil
    }

    // MARK: - API Key

    static func hasAPIKey() -> Bool {
        apiKey()?.isEmpty == false
    }

    static func apiKey() -> String? {
        cacheLock.lock()
        if apiKeyLoaded {
            let cached = apiKeyCache
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var value: String?
        if let text = WeatherSecretStore.secrets().apiKey {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            value = trimmed.isEmpty ? nil : trimmed
        }
        cacheLock.lock()
        apiKeyCache = value
        apiKeyLoaded = true
        cacheLock.unlock()
        return value
    }

    static func saveAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            WeatherSecretStore.setAPIKey(nil)
            return
        }
        WeatherSecretStore.setAPIKey(trimmed)
        cacheLock.lock()
        apiKeyCache = trimmed
        apiKeyLoaded = true
        cacheLock.unlock()
    }

    static func clearAPIKey() {
        WeatherSecretStore.setAPIKey(nil)
        cacheLock.lock()
        apiKeyCache = nil
        apiKeyLoaded = true
        cacheLock.unlock()
    }

    static func privateKey() throws -> Curve25519.Signing.PrivateKey {
        cacheLock.lock()
        if privateKeyLoaded {
            let cached = privateKeyCache
            cacheLock.unlock()
            guard let cached else { throw QWeatherAuthError.missingPrivateKey }
            return cached
        }
        cacheLock.unlock()

        guard let encoded = WeatherSecretStore.secrets().privateKey,
              let data = Data(base64Encoded: encoded) else {
            cacheLock.lock()
            privateKeyLoaded = true
            privateKeyCache = nil
            cacheLock.unlock()
            throw QWeatherAuthError.missingPrivateKey
        }
        let key: Curve25519.Signing.PrivateKey
        do {
            key = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } catch {
            cacheLock.lock()
            privateKeyLoaded = true
            privateKeyCache = nil
            cacheLock.unlock()
            throw QWeatherAuthError.invalidPrivateKey
        }
        cacheLock.lock()
        privateKeyLoaded = true
        privateKeyCache = key
        cacheLock.unlock()
        return key
    }

    /// 生成新的 Ed25519 密钥对，私钥写入本机凭据文件，返回公钥 PEM。
    static func regenerateKeyPair() throws -> String {
        let key = Curve25519.Signing.PrivateKey()
        WeatherSecretStore.setPrivateKey(key.rawRepresentation.base64EncodedString())
        cacheLock.lock()
        privateKeyCache = key
        privateKeyLoaded = true
        cacheLock.unlock()
        return publicKeyPEM(for: key)
    }

    static func publicKeyPEM() throws -> String {
        publicKeyPEM(for: try privateKey())
    }

    static func publicKeyPEM(for key: Curve25519.Signing.PrivateKey) -> String {
        var der = spkiPrefix
        der.append(key.publicKey.rawRepresentation)
        let base64 = der.base64EncodedString()
        let lines = stride(from: 0, to: base64.count, by: 64).map { offset -> String in
            let start = base64.index(base64.startIndex, offsetBy: offset)
            let end = base64.index(start, offsetBy: min(64, base64.count - offset))
            return String(base64[start..<end])
        }
        return "-----BEGIN PUBLIC KEY-----\n\(lines.joined(separator: "\n"))\n-----END PUBLIC KEY-----"
    }

    static func makeJWT(issuer: String,
                        projectID: String,
                        keyID: String,
                        privateKey: Curve25519.Signing.PrivateKey,
                        now: Date = Date()) throws -> String {
        let issuedAt = Int(now.timeIntervalSince1970) - 30
        let expiresAt = issuedAt + 24 * 60 * 60
        let header: [String: Any] = ["alg": "EdDSA", "kid": keyID]
        let payload: [String: Any] = [
            "iss": issuer,
            "sub": projectID,
            "iat": issuedAt,
            "exp": expiresAt
        ]
        guard let headerData = try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            throw QWeatherAuthError.encodingFailed
        }
        let signingInput = base64URL(headerData) + "." + base64URL(payloadData)
        guard let signingData = signingInput.data(using: .utf8) else {
            throw QWeatherAuthError.encodingFailed
        }
        let signature = try privateKey.signature(for: signingData)
        return signingInput + "." + base64URL(signature)
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
