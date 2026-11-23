import Foundation

/// 天气凭据存储：仅当前用户可读的 0600 文件。
/// 自签名 App 每次重建都会让钥匙串 ACL 失效并索要登录密码，因此这里不使用钥匙串。
struct WeatherSecrets: Codable {
    var apiKey: String?
    var privateKey: String?
}

enum WeatherSecretStore {
    private static let lock = NSLock()
    private static var cache: WeatherSecrets?
    private static var loaded = false

    static var fileURL: URL {
        ConfigStore.defaultDirectory().appendingPathComponent("weather-secrets.json")
    }

    static func secrets() -> WeatherSecrets {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        return cache ?? WeatherSecrets()
    }

    static func setAPIKey(_ value: String?) {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        var secrets = cache ?? WeatherSecrets()
        secrets.apiKey = value
        cache = secrets
        persistLocked(secrets)
    }

    static func setPrivateKey(_ value: String?) {
        lock.lock()
        defer { lock.unlock() }
        ensureLoadedLocked()
        var secrets = cache ?? WeatherSecrets()
        secrets.privateKey = value
        cache = secrets
        persistLocked(secrets)
    }

    // MARK: - 内部

    private static func ensureLoadedLocked() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WeatherSecrets.self, from: data) else {
            cache = WeatherSecrets()
            return
        }
        cache = decoded
    }

    private static func persistLocked(_ secrets: WeatherSecrets) {
        let url = fileURL
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        guard let data = try? JSONEncoder().encode(secrets) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? data.write(to: url, options: [.atomic])
        } else {
            FileManager.default.createFile(atPath: url.path,
                                           contents: data,
                                           attributes: [.posixPermissions: 0o600])
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
