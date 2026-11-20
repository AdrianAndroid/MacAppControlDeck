import Foundation

/// 上游 macshot 的文件名模板：{date} {time} {timestamp} {unix} {window}
/// {app} {index} {random} {yyyy} {MM} {dd} {HH} {mm} {ss} {ms}；
/// 模板中的 `/` 会生成子文件夹（`{yyyy}/{MM}/...`）。
enum FilenameFormatter {
    static let defaultTemplate = "Screenshot {date} at {time}"
    static let userDefaultsKey = "capture.filenameTemplate"

    static let defaultRecordingTemplate = "Recording {date} at {time}"
    static let recordingUserDefaultsKey = "capture.recordingFilenameTemplate"

    static let noAppUserDefaultsKey = "capture.filenameTemplateNoApp"
    static let recordingNoAppUserDefaultsKey = "capture.recordingFilenameTemplateNoApp"

    static func format(template: String,
                       windowTitle: String? = nil,
                       appName: String? = nil,
                       index: Int? = nil,
                       date: Date = Date(),
                       fallback: String = defaultTemplate) -> String {
        let effective = template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : template
        let rendered = render(template: effective, windowTitle: windowTitle,
                              appName: appName, index: index, date: date)
        let sanitized = FilenameSanitizer.sanitize(rendered)
        if sanitized.isEmpty, effective != fallback {
            return format(template: fallback, windowTitle: windowTitle,
                          appName: appName, index: index, date: date, fallback: fallback)
        }
        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    static func formatRelativePath(template: String,
                                   noAppTemplate: String? = nil,
                                   windowTitle: String? = nil,
                                   appName: String? = nil,
                                   index: Int? = nil,
                                   date: Date = Date(),
                                   fallback: String = defaultTemplate) -> [String] {
        var effective = template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : template
        let hasApp = !(appName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if !hasApp, effective.contains("{app}"),
           let noApp = noAppTemplate?.trimmingCharacters(in: .whitespacesAndNewlines), !noApp.isEmpty {
            effective = noApp
        }
        let pieces = effective.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        var components: [String] = []
        for piece in pieces {
            let rendered = render(template: piece, windowTitle: windowTitle,
                                  appName: appName, index: index, date: date)
            let sanitized = FilenameSanitizer.sanitize(rendered)
            guard !sanitized.isEmpty, sanitized != ".", sanitized != ".." else { continue }
            components.append(sanitized)
        }
        if components.isEmpty {
            return [format(template: fallback, windowTitle: windowTitle,
                           appName: appName, index: index, date: date, fallback: fallback)]
        }
        return components
    }

    static func appNameForTemplate(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        let ownName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return trimmed == ownName ? nil : trimmed
    }

    static func template(forRecording: Bool) -> String {
        let key = forRecording ? recordingUserDefaultsKey : userDefaultsKey
        return UserDefaults.standard.string(forKey: key) ?? (forRecording ? defaultRecordingTemplate : defaultTemplate)
    }

    static func makeURL(directory: URL,
                        template: String,
                        windowTitle: String? = nil,
                        appName: String? = nil,
                        index: Int? = nil,
                        fileExtension: String) throws -> URL {
        let fallback = FilenameFormatter.template(forRecording: false)
        let components = formatRelativePath(template: template.isEmpty ? fallback : template,
                                            windowTitle: windowTitle,
                                            appName: appName,
                                            index: index)
        let base = directory.appendingPathComponent(components.dropLast().joined(separator: "/"),
                                                    isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let name = components.last ?? "Untitled"
        var url = base.appendingPathComponent("\(name).\(fileExtension)")
        var suffix = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = base.appendingPathComponent("\(name) \(suffix).\(fileExtension)")
            suffix += 1
        }
        return url
    }

    private static func render(template: String,
                               windowTitle: String?,
                               appName: String?,
                               index: Int?,
                               date: Date) -> String {
        let dateStr = dateFormatter("yyyy-MM-dd").string(from: date)
        let timeStr = dateFormatter("HH-mm-ss").string(from: date)
        let window = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let app = appName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let millis = Int((date.timeIntervalSince1970 * 1000).rounded(.down)) % 1000

        let values: [String: String] = [
            "{date}": dateStr,
            "{time}": timeStr,
            "{timestamp}": "\(dateStr)_\(timeStr)",
            "{unix}": String(Int(date.timeIntervalSince1970)),
            "{window}": window,
            "{app}": app,
            "{index}": index.map(String.init) ?? "",
            "{yyyy}": dateFormatter("yyyy").string(from: date),
            "{MM}": dateFormatter("MM").string(from: date),
            "{dd}": dateFormatter("dd").string(from: date),
            "{HH}": dateFormatter("HH").string(from: date),
            "{mm}": dateFormatter("mm").string(from: date),
            "{ss}": dateFormatter("ss").string(from: date),
            "{ms}": String(format: "%03d", Int32(millis)),
        ]

        var out = ""
        var cursor = template.startIndex
        while let open = template[cursor...].firstIndex(of: "{") {
            out += template[cursor..<open]
            guard let close = template[open...].firstIndex(of: "}") else {
                out += template[open...]
                cursor = template.endIndex
                break
            }
            let token = String(template[open...close])
            out += token == "{random}" ? randomToken() : (values[token] ?? token)
            cursor = template.index(after: close)
        }
        out += template[cursor...]
        return out
    }

    private static let randomAlphabet: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyz")

    private static func randomToken(length: Int = 8) -> String {
        var s = ""
        s.reserveCapacity(length)
        for _ in 0..<length {
            s.append(randomAlphabet[Int.random(in: 0..<randomAlphabet.count)])
        }
        return s
    }

    private static func dateFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}
