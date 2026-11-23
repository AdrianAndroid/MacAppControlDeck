import Foundation

struct WeatherNowDTO: Codable, Equatable, Sendable {
    var temp: Int?
    var text: String
    var icon: String?
    var feelsLike: Int?
    var humidity: Int?
}

struct WeatherDayDTO: Codable, Equatable, Sendable, Identifiable {
    var date: String?
    var text: String
    var icon: String?
    var max: Int?
    var min: Int?
    var precipProbability: Int?

    var id: String { (date ?? "") + "|" + text }
}

struct WeatherHourDTO: Codable, Equatable, Sendable, Identifiable {
    var time: String
    var temp: Int?
    var icon: String?
    var text: String

    var id: String { time }
}

struct WeatherCity: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var province: String
    var district: String
    var latitude: Double
    var longitude: Double

    var displayName: String {
        var parts: [String] = []
        for part in [province, district, name] where !part.isEmpty && !parts.contains(part) {
            parts.append(part)
        }
        return parts.joined(separator: " · ")
    }
}

struct WeatherPayload: Codable, Equatable, Sendable {
    var city: String
    var now: WeatherNowDTO
    var today: WeatherDayDTO?
    var daily: [WeatherDayDTO]
    var hourly: [WeatherHourDTO]? = nil
    var updatedAt: String
    var attribution: String
}

/// 和风 v1 的 JSON schema 没在文档里给全，这里按“新结构优先、旧字段回退”解析。
enum WeatherParsing {
    // MARK: - 实时

    static func parseNow(root: [String: Any]) -> WeatherNowDTO? {
        let node = dictionary(root["now"]) ?? dictionary(root["current"]) ?? root
        let temp = int(path(node, ["temperature", "value"]))
            ?? int(node["temp"])
            ?? int(node["temperature"])
        let text = string(path(node, ["condition", "text"]))
            ?? string(node["text"])
            ?? string(node["weather"])
            ?? string(path(node, ["condition", "description"]))
        guard temp != nil || text != nil else { return nil }

        let rawHumidity = double(node["humidity"])
        var humidity: Int?
        if let raw = rawHumidity {
            humidity = raw <= 1 ? Int((raw * 100).rounded()) : Int(raw.rounded())
        }
        let feelsLike = int(path(node, ["feelsLike", "value"]))
            ?? int(node["feelsLike"])
            ?? int(path(node, ["temperature", "feelsLike"]))

        return WeatherNowDTO(temp: temp,
                             text: text ?? "—",
                             icon: iconString(path(node, ["condition", "icon"]))
                                ?? iconString(path(node, ["condition", "code"]))
                                ?? iconString(node["icon"]),
                             feelsLike: feelsLike,
                             humidity: humidity)
    }

    // MARK: - 小时预报

    static func parseHourly(root: [String: Any]) -> [WeatherHourDTO] {
        let items = (root["hours"] as? [Any])
            ?? (root["hourly"] as? [Any])
            ?? (root["data"] as? [Any])
            ?? []
        return items.compactMap { item -> WeatherHourDTO? in
            guard let dict = item as? [String: Any] else { return nil }
            let time = string(dict["forecastTime"])
                ?? string(dict["time"])
                ?? string(dict["fxTime"])
            let temp = int(path(dict, ["temperature", "value"]))
                ?? int(dict["temp"])
                ?? int(dict["temperature"])
            let text = string(path(dict, ["condition", "text"]))
                ?? string(dict["text"])
                ?? string(dict["weather"])
            let icon = iconString(path(dict, ["condition", "code"]))
                ?? iconString(path(dict, ["condition", "icon"]))
                ?? iconString(dict["icon"])
            guard let time, temp != nil || text != nil else { return nil }
            return WeatherHourDTO(time: time, temp: temp, icon: icon, text: text ?? "—")
        }
        .sorted { $0.time < $1.time }
    }

    // MARK: - 预报

    static func parseDaily(root: Any) -> [WeatherDayDTO] {
        var items: [Any] = []
        if let array = root as? [Any] {
            items = array
        } else if let dict = root as? [String: Any] {
            for key in ["daily", "forecast", "days", "data", "list"] {
                if let array = dict[key] as? [Any] { items = array; break }
            }
            if items.isEmpty, dict["forecastStartTime"] != nil { items = [dict] }
        }

        return items.compactMap { item -> WeatherDayDTO? in
            guard let dict = item as? [String: Any] else { return nil }
            let maxValue = int(path(dict, ["temperature", "max", "value"]))
                ?? int(path(dict, ["temperatureMax", "value"]))
                ?? int(dict["tempMax"])
                ?? int(dict["temperatureMax"])
            let minValue = int(path(dict, ["temperature", "min", "value"]))
                ?? int(path(dict, ["temperatureMin", "value"]))
                ?? int(dict["tempMin"])
                ?? int(dict["temperatureMin"])
            let text = string(path(dict, ["daytime", "condition", "text"]))
                ?? string(path(dict, ["nighttime", "condition", "text"]))
                ?? string(path(dict, ["day", "condition", "text"]))
                ?? string(dict["textDay"])
                ?? string(path(dict, ["condition", "text"]))
                ?? string(dict["text"])
            let icon = iconString(path(dict, ["daytime", "condition", "code"]))
                ?? iconString(path(dict, ["nighttime", "condition", "code"]))
                ?? iconString(path(dict, ["daytime", "condition", "icon"]))
                ?? iconString(path(dict, ["day", "condition", "icon"]))
                ?? iconString(dict["iconDay"])
                ?? iconString(path(dict, ["condition", "code"]))
                ?? iconString(path(dict, ["condition", "icon"]))
            guard maxValue != nil || minValue != nil || text != nil else { return nil }

            let rawProbability = double(path(dict, ["daytime", "precipitation", "probability"]))
                ?? double(path(dict, ["nighttime", "precipitation", "probability"]))
                ?? double(path(dict, ["day", "precipitation", "probability"]))
                ?? double(path(dict, ["precipitation", "probability"]))
                ?? double(dict["precipProbability"])
                ?? double(dict["pop"])
            var probability: Int?
            if let raw = rawProbability {
                probability = raw <= 1 ? Int((raw * 100).rounded()) : Int(raw.rounded())
            }

            return WeatherDayDTO(date: dayString(dict),
                                 text: text ?? "—",
                                 icon: icon,
                                 max: maxValue,
                                 min: minValue,
                                 precipProbability: probability)
        }
        .sorted { lhs, rhs in
            (lhs.date ?? "") < (rhs.date ?? "")
        }
    }

    // MARK: - 城市

    static func parseCities(root: [String: Any]) -> [WeatherCity] {
        let items = (root["location"] as? [Any])
            ?? (root["locations"] as? [Any])
            ?? (root["data"] as? [Any])
            ?? []
        return items.compactMap { item -> WeatherCity? in
            guard let dict = item as? [String: Any] else { return nil }
            let name = string(dict["name"]) ?? string(dict["city"]) ?? ""
            guard !name.isEmpty else { return nil }
            guard let lat = double(dict["lat"]) ?? double(dict["latitude"]),
                  let lon = double(dict["lon"]) ?? double(dict["longitude"]) else { return nil }
            return WeatherCity(id: string(dict["id"]) ?? string(dict["locationId"]) ?? "\(lat),\(lon)",
                               name: name,
                               province: string(dict["adm1"]) ?? string(dict["province"]) ?? "",
                               district: string(dict["adm2"]) ?? string(dict["district"]) ?? "",
                               latitude: lat,
                               longitude: lon)
        }
    }

    // MARK: - 工具

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    static func path(_ root: [String: Any], _ keys: [String]) -> Any? {
        var current: Any? = root
        for key in keys {
            guard let dict = current as? [String: Any] else { return nil }
            current = dict[key]
        }
        return current
    }

    static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return Int(number.doubleValue.rounded()) }
        if let string = value as? String {
            let cleaned = string.trimmingCharacters(in: .whitespaces)
            if let double = Double(cleaned) { return Int(double.rounded()) }
        }
        return nil
    }

    static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    static func string(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func iconString(_ value: Any?) -> String? {
        if let number = value as? NSNumber { return String(number.intValue) }
        return string(value)
    }

    static func dayString(_ item: [String: Any]) -> String? {
        if let raw = string(item["forecastStartTime"]) ?? string(item["date"]) ?? string(item["fxDate"]) {
            if let date = parseDate(raw) {
                return dayFormatter.string(from: date)
            }
            if raw.count >= 10 { return String(raw.prefix(10)) }
        }
        return nil
    }

    static func parseDate(_ raw: String) -> Date? {
        if let date = isoFormatter.date(from: raw) { return date }
        if let date = isoFractional.date(from: raw) { return date }
        for format in ["yyyy-MM-dd'T'HH:mmXXXXX", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: raw)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
