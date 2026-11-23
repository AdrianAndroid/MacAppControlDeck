import Foundation

struct WeatherEnvelope: Codable, Equatable, Sendable {
    var ok: Bool
    var stale: Bool? = nil
    var updatedAt: String? = nil
    var city: String? = nil
    var now: WeatherNowDTO? = nil
    var today: WeatherDayDTO? = nil
    var daily: [WeatherDayDTO]? = nil
    var hourly: [WeatherHourDTO]? = nil
    var attribution: String? = nil
    var reason: String? = nil
    var message: String? = nil
}

enum WeatherServiceError: LocalizedError {
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先填写和风 API Host、JWT 凭据并选择城市"
        }
    }
}

/// 负责 JWT 缓存、10 分钟数据缓存、单飞与失败退避。
actor WeatherService {
    static let shared = WeatherService()

    private struct Cached {
        let key: String
        let payload: WeatherPayload
        let date: Date
    }

    private var cached: Cached?
    private var lastFailure: Date?
    private var tokenCache: (key: String, expiresAt: Date, token: String)?
    private var inflight: Task<WeatherEnvelope, Never>?
    private var inflightKey: String?

    private let freshInterval: TimeInterval = 5 * 60
    private let retryInterval: TimeInterval = 60

    func snapshot(for config: WeatherConfig, force: Bool = false) async -> WeatherEnvelope {
        guard config.isConfigured else {
            return WeatherEnvelope(ok: false, reason: "not-configured")
        }
        let key = config.cacheKey
        let now = Date()

        if !force, let cached, cached.key == key, now.timeIntervalSince(cached.date) < freshInterval {
            return envelope(cached.payload, stale: false)
        }
        if !force, let lastFailure, now.timeIntervalSince(lastFailure) < retryInterval,
           let cached, cached.key == key {
            return envelope(cached.payload, stale: true)
        }
        if inflightKey == key, let inflight {
            return await inflight.value
        }

        let task = Task { await self.refresh(config: config) }
        inflight = task
        inflightKey = key
        let result = await task.value
        if inflightKey == key {
            inflight = nil
            inflightKey = nil
        }
        return result
    }

    func lookupCities(for config: WeatherConfig, query: String) async throws -> [WeatherCity] {
        guard config.canAuthenticate else { throw WeatherServiceError.notConfigured }
        let credential = try credential(for: config)
        return try await QWeatherClient(config: config, credential: credential).lookupCities(query: query)
    }

    func invalidate() {
        cached = nil
        lastFailure = nil
        tokenCache = nil
        inflight?.cancel()
        inflight = nil
        inflightKey = nil
    }

    // MARK: - 内部

    private func refresh(config: WeatherConfig) async -> WeatherEnvelope {
        do {
            let credential = try credential(for: config)
            let client = QWeatherClient(config: config, credential: credential)
            let result = try await client.fetchAll()
            let payload = WeatherPayload(city: config.cityName,
                                         now: result.now,
                                         today: result.daily.first,
                                         daily: Array(result.daily.prefix(5)),
                                         hourly: Array(result.hourly.prefix(8)),
                                         updatedAt: Self.isoFormatter.string(from: Date()),
                                         attribution: "和风天气")
            cached = Cached(key: config.cacheKey, payload: payload, date: Date())
            lastFailure = nil
            return envelope(payload, stale: false)
        } catch {
            lastFailure = Date()
            let message = Self.friendlyMessage(error)
            if let cached, cached.key == config.cacheKey {
                var stale = envelope(cached.payload, stale: true)
                stale.message = message
                return stale
            }
            return WeatherEnvelope(ok: false, reason: "upstream", message: message)
        }
    }

    private func credential(for config: WeatherConfig) throws -> QWeatherClient.Credential {
        switch config.authMode {
        case .apiKey:
            guard let key = QWeatherAuth.apiKey() else { throw QWeatherAuthError.missingAPIKey }
            return .apiKey(key)
        case .jwt:
            return .bearer(try token(for: config))
        }
    }

    private func token(for config: WeatherConfig) throws -> String {
        let key = "\(config.normalizedHost)|\(config.issuer)|\(config.projectID)|\(config.keyID)"
        if let tokenCache, tokenCache.key == key,
           tokenCache.expiresAt > Date().addingTimeInterval(60) {
            return tokenCache.token
        }
        let privateKey = try QWeatherAuth.privateKey()
        let jwt = try QWeatherAuth.makeJWT(issuer: config.issuer,
                                           projectID: config.projectID,
                                           keyID: config.keyID,
                                           privateKey: privateKey)
        tokenCache = (key: key, expiresAt: Date().addingTimeInterval(86300), token: jwt)
        return jwt
    }

    static func friendlyMessage(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .dnsLookupFailed:
                return "无法解析 API Host：请确认它是控制台「设置」里的专属域名，不是文档示例"
            case .notConnectedToInternet, .networkConnectionLost:
                return "Mac 当前无法联网"
            case .timedOut:
                return "请求和风天气超时，请检查网络"
            case .secureConnectionFailed, .serverCertificateUntrusted:
                return "与和风天气的 TLS 连接失败"
            default:
                break
            }
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    private func envelope(_ payload: WeatherPayload, stale: Bool) -> WeatherEnvelope {
        WeatherEnvelope(ok: true,
                        stale: stale,
                        updatedAt: payload.updatedAt,
                        city: payload.city,
                        now: payload.now,
                        today: payload.today,
                        daily: payload.daily,
                        hourly: payload.hourly,
                        attribution: payload.attribution)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
