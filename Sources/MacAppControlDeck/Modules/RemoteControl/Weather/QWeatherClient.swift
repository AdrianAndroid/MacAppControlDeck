import Foundation

enum QWeatherClientError: LocalizedError {
    case badHost
    case http(status: Int, body: String)
    case invalidResponse
    case upstream(code: String, message: String)
    case decodeFailed(String)
    case missingToken

    var errorDescription: String? {
        switch self {
        case .badHost:
            return "API Host 格式不正确"
        case let .http(status, body):
            return "和风返回 HTTP \(status)\(body.isEmpty ? "" : "：\(body)")"
        case .invalidResponse:
            return "和风返回的不是 JSON 对象"
        case let .upstream(code, message):
            return "和风错误 \(code)\(message.isEmpty ? "" : "：\(message)")"
        case let .decodeFailed(message):
            return message
        case .missingToken:
            return "缺少和风 JWT"
        }
    }
}

struct QWeatherClient {
    enum Credential {
        case bearer(String)
        case apiKey(String)
    }

    let config: WeatherConfig
    let credential: Credential

    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    func fetchAll() async throws -> (now: WeatherNowDTO, daily: [WeatherDayDTO], hourly: [WeatherHourDTO]) {
        let lat = Self.coordinate(config.latitude)
        let lon = Self.coordinate(config.longitude)
        async let nowRoot = get(path: "/weather/v1/current/\(lat)/\(lon)")
        async let dailyRoot = get(path: "/weather/v1/daily/\(lat)/\(lon)")
        async let hourlyRoot = optional(path: "/weather/v1/hourly/\(lat)/\(lon)")
        let (nowJSON, dailyJSON, hourlyJSON) = try await (nowRoot, dailyRoot, hourlyRoot)

        guard let now = WeatherParsing.parseNow(root: nowJSON) else {
            throw QWeatherClientError.decodeFailed("实时天气缺少温度或天气现象，返回字段可能已变化")
        }
        let daily = WeatherParsing.parseDaily(root: dailyJSON)
        guard !daily.isEmpty else {
            throw QWeatherClientError.decodeFailed("日预报为空，返回字段可能已变化")
        }
        let hourly = WeatherParsing.parseHourly(root: hourlyJSON ?? [:])
        return (now, daily, hourly)
    }

    /// 小时预报失败不影响实时与日预报：返回 nil，页面自动隐藏小时条。
    private func optional(path: String) async -> [String: Any]? {
        try? await get(path: path)
    }

    func lookupCities(query: String) async throws -> [WeatherCity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let root = try await get(path: "/geo/v2/city/lookup",
                                 query: [URLQueryItem(name: "location", value: trimmed),
                                         URLQueryItem(name: "number", value: "10")])
        return WeatherParsing.parseCities(root: root)
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> [String: Any] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = config.normalizedHost
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw QWeatherClientError.badHost }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        switch credential {
        case let .bearer(token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case let .apiKey(key):
            request.setValue(key, forHTTPHeaderField: "X-QW-Api-Key")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MacAppControlDeck/0.3.1 (screen-weather)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw QWeatherClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QWeatherClientError.http(status: http.statusCode, body: Self.snippet(data))
        }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw QWeatherClientError.invalidResponse
        }
        if let rawCode = root["code"] {
            let code = String(describing: rawCode)
            if code != "200" {
                throw QWeatherClientError.upstream(code: code, message: Self.message(from: root))
            }
        }
        return root
    }

    private static func coordinate(_ value: Double?) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value ?? 0)
    }

    private static func message(from root: [String: Any]) -> String {
        for key in ["message", "error", "detail", "description"] {
            if let value = root[key] as? String, !value.isEmpty { return value }
            if let nested = root[key] as? [String: Any] {
                for inner in ["message", "detail", "description"] {
                    if let value = nested[inner] as? String, !value.isEmpty { return value }
                }
            }
        }
        return ""
    }

    private static func snippet(_ data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? ""
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(singleLine.prefix(180))
    }
}
