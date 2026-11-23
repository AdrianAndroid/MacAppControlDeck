import Combine
import Foundation

enum WeatherAuthMode: String, CaseIterable, Identifiable, Sendable {
    case apiKey
    case jwt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiKey: return "API Key"
        case .jwt: return "JWT（Ed25519）"
        }
    }
}

struct WeatherConfig: Sendable, Equatable {
    var enabled: Bool
    var host: String
    var authMode: WeatherAuthMode
    var issuer: String
    var projectID: String
    var keyID: String
    var cityName: String
    var latitude: Double?
    var longitude: Double?
    var hasAPIKey: Bool
    var hasPrivateKey: Bool

    static let empty = WeatherConfig(enabled: false, host: "", authMode: .apiKey,
                                     issuer: "", projectID: "", keyID: "",
                                     cityName: "", latitude: nil, longitude: nil,
                                     hasAPIKey: false, hasPrivateKey: false)

    var normalizedHost: String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://"] where value.lowercased().hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
        }
        if let slash = value.firstIndex(of: "/") { value = String(value[..<slash]) }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    var isConfigured: Bool {
        canAuthenticate && enabled && latitude != nil && longitude != nil && hostValidationMessage == nil
    }

    var hostValidationMessage: String? {
        let host = normalizedHost
        guard !host.isEmpty else { return nil }
        if host == "h2a9cf3mhs.xy.qweatherapi.com" || host.hasPrefix("abcxyz.") {
            return "这是文档示例 Host，请换成控制台「设置」里的专属 Host"
        }
        if !host.lowercased().hasSuffix("qweatherapi.com") {
            return "Host 应形如 xxxx.qweatherapi.com"
        }
        return nil
    }

    var canAuthenticate: Bool {
        guard !normalizedHost.isEmpty, hostValidationMessage == nil else { return false }
        switch authMode {
        case .apiKey:
            return hasAPIKey
        case .jwt:
            return hasPrivateKey
                && !issuer.isEmpty
                && !projectID.isEmpty
                && !keyID.isEmpty
        }
    }

    /// 缓存与凭据绑定：认证方式、城市、Host 或项目变化时不能复用旧数据。
    var cacheKey: String {
        let lat = latitude.map { String(format: "%.2f", $0) } ?? "-"
        let lon = longitude.map { String(format: "%.2f", $0) } ?? "-"
        let identity = authMode == .jwt ? "\(issuer)|\(projectID)|\(keyID)|\(hasPrivateKey)" : "key|\(hasAPIKey)"
        return "\(normalizedHost)|\(authMode.rawValue)|\(identity)|\(lat)|\(lon)"
    }
}

@MainActor
final class WeatherSettings: ObservableObject {
    static let shared = WeatherSettings()

    private enum Key {
        static let enabled = "screen.weather.enabled"
        static let host = "screen.weather.host"
        static let authMode = "screen.weather.authMode"
        static let issuer = "screen.weather.issuer"
        static let projectID = "screen.weather.projectID"
        static let keyID = "screen.weather.keyID"
        static let cityName = "screen.weather.cityName"
        static let latitude = "screen.weather.latitude"
        static let longitude = "screen.weather.longitude"
    }

    private let defaults: UserDefaults

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var host: String { didSet { defaults.set(host, forKey: Key.host) } }
    @Published var authMode: WeatherAuthMode {
        didSet { defaults.set(authMode.rawValue, forKey: Key.authMode) }
    }
    @Published var issuer: String { didSet { defaults.set(issuer, forKey: Key.issuer) } }
    @Published var projectID: String { didSet { defaults.set(projectID, forKey: Key.projectID) } }
    @Published var keyID: String { didSet { defaults.set(keyID, forKey: Key.keyID) } }
    @Published var cityName: String { didSet { defaults.set(cityName, forKey: Key.cityName) } }
    @Published var latitude: Double? {
        didSet { defaults.set(latitude, forKey: Key.latitude) }
    }
    @Published var longitude: Double? {
        didSet { defaults.set(longitude, forKey: Key.longitude) }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? false
        host = defaults.string(forKey: Key.host) ?? ""
        authMode = WeatherAuthMode(rawValue: defaults.string(forKey: Key.authMode) ?? "") ?? .apiKey
        issuer = defaults.string(forKey: Key.issuer) ?? ""
        projectID = defaults.string(forKey: Key.projectID) ?? ""
        keyID = defaults.string(forKey: Key.keyID) ?? ""
        cityName = defaults.string(forKey: Key.cityName) ?? ""
        latitude = defaults.object(forKey: Key.latitude) as? Double
        longitude = defaults.object(forKey: Key.longitude) as? Double
    }

    var config: WeatherConfig {
        WeatherConfig(enabled: enabled,
                      host: host,
                      authMode: authMode,
                      issuer: issuer,
                      projectID: projectID,
                      keyID: keyID,
                      cityName: cityName,
                      latitude: latitude,
                      longitude: longitude,
                      hasAPIKey: authMode == .apiKey ? QWeatherAuth.hasAPIKey() : false,
                      hasPrivateKey: authMode == .jwt ? QWeatherAuth.hasPrivateKey() : false)
    }

    func select(city: WeatherCity) {
        cityName = city.name
        latitude = city.latitude
        longitude = city.longitude
    }
}
