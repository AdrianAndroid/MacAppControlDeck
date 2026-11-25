import Combine
import Foundation

/// 副屏外观：横屏四个模块的边框开关与强度（0 = 无框，0.30 = 最明显）。
struct ScreenFrameConfig: Codable, Equatable {
    var enabled: Bool
    var strength: Double

    static let `default` = ScreenFrameConfig(enabled: true, strength: 0.16)
}

final class ScreenAppearanceSettings: ObservableObject {
    static let shared = ScreenAppearanceSettings()

    private enum Key {
        static let enabled = "screen.frame.enabled"
        static let strength = "screen.frame.strength"
    }

    private let defaults: UserDefaults
    private var loading = true

    @Published var enabled: Bool { didSet { save(Key.enabled, enabled) } }
    @Published var strength: Double { didSet { save(Key.strength, min(0.30, max(0, strength))) } }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = ScreenFrameConfig.default
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? fallback.enabled
        strength = defaults.object(forKey: Key.strength) as? Double ?? fallback.strength
        loading = false
    }

    var config: ScreenFrameConfig {
        ScreenFrameConfig(enabled: enabled, strength: min(0.30, max(0, strength)))
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        guard !loading else { return }
        ScreenEventHub.notifyChange()
    }
}
