import Foundation

/// 全局快捷键配置落盘：`~/Library/Application Support/MacAppControlDeck/hotkeys.json`。
final class GlobalHotKeyStore {
    private let url: URL

    init(directory: URL? = nil) {
        let base = directory ?? ConfigStore.defaultDirectory()
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        url = base.appendingPathComponent("hotkeys.json")
    }

    var fileURL: URL { url }

    func load() -> GlobalHotKeyPreferences? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(GlobalHotKeyPreferences.self, from: data)
    }

    func save(_ preferences: GlobalHotKeyPreferences) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preferences) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
