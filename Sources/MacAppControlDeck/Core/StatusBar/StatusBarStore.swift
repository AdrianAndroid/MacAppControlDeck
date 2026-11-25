import Combine
import Foundation

/// 状态栏条目开关的公共存储：与模块开关解耦，模块关闭不丢用户勾选。
@MainActor
final class StatusBarStore: ObservableObject {
    static let shared = StatusBarStore()

    @Published private(set) var values: [String: Bool] = [:]

    private let defaults: UserDefaults
    private let prefix = "statusbar."

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyKeysIfNeeded()
        loadAll()
    }

    /// 老版本 PureMac 的三个开关迁移到公共键，保证升级后勾选状态不丢。
    private func migrateLegacyKeysIfNeeded() {
        let pairs = [
            ("systemTool.cpu", "systemTool.menubar.showCPU"),
            ("systemTool.mem", "systemTool.menubar.showMEM"),
            ("systemTool.net", "systemTool.menubar.showNetSpeed")
        ]
        for (newID, legacyKey) in pairs {
            let newKey = prefix + newID
            guard defaults.object(forKey: newKey) == nil,
                  let legacy = defaults.object(forKey: legacyKey) as? Bool else { continue }
            defaults.set(legacy, forKey: newKey)
        }
    }

    private func loadAll() {
        var stored: [String: Bool] = [:]
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            if let value = defaults.object(forKey: key) as? Bool {
                stored[String(key.dropFirst(prefix.count))] = value
            }
        }
        values = stored
    }

    func isVisible(_ entry: StatusBarEntry) -> Bool {
        values[entry.id] ?? entry.defaultVisible
    }

    func setVisible(_ visible: Bool, for entry: StatusBarEntry) {
        values[entry.id] = visible
        defaults.set(visible, forKey: prefix + entry.id)
    }
}
