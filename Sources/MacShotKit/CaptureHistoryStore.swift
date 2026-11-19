import Foundation

/// 本地截图历史，只记录文件路径，不注册任何网络服务。
public final class CaptureHistoryStore {
    public static let shared = CaptureHistoryStore()

    private let key = "capture.history.paths"
    private let limit = 30
    private let defaults = UserDefaults.standard

    private init() {}

    public var urls: [URL] {
        (defaults.stringArray(forKey: key) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    public func add(_ url: URL) {
        var paths = defaults.stringArray(forKey: key) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        if paths.count > limit { paths = Array(paths.prefix(limit)) }
        defaults.set(paths, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
