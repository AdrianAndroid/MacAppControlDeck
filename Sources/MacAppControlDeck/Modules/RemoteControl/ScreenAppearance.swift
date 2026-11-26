import Combine
import Foundation

/// 副屏外观：横屏四个模块的边框开关与强度（0 = 无框，0.30 = 最明显），
/// 以及视口四边内边距（px，0 = 内容铺满视口）。
struct ScreenFrameConfig: Codable, Equatable {
    var enabled: Bool
    var strength: Double
    /// 走查用：紧贴视口四边的 1px 外框，不占布局，默认关闭。
    var viewportBorder: Bool = false
    var paddingTop: Int = 0
    var paddingRight: Int = 0
    var paddingBottom: Int = 0
    var paddingLeft: Int = 0

    static let paddingRange = 0...120

    static let `default` = ScreenFrameConfig(enabled: true, strength: 0.16, viewportBorder: false)

    static func clampPadding(_ value: Int) -> Int {
        min(paddingRange.upperBound, max(paddingRange.lowerBound, value))
    }

    var normalized: ScreenFrameConfig {
        var value = self
        value.strength = min(0.30, max(0, value.strength))
        value.paddingTop = Self.clampPadding(value.paddingTop)
        value.paddingRight = Self.clampPadding(value.paddingRight)
        value.paddingBottom = Self.clampPadding(value.paddingBottom)
        value.paddingLeft = Self.clampPadding(value.paddingLeft)
        return value
    }
}

final class ScreenAppearanceSettings: ObservableObject {
    static let shared = ScreenAppearanceSettings()

    private enum Key {
        static let enabled = "screen.frame.enabled"
        static let strength = "screen.frame.strength"
        static let viewportBorder = "screen.frame.viewportBorder"
        static let paddingTop = "screen.frame.paddingTop"
        static let paddingRight = "screen.frame.paddingRight"
        static let paddingBottom = "screen.frame.paddingBottom"
        static let paddingLeft = "screen.frame.paddingLeft"
    }

    private let defaults: UserDefaults
    private var loading = true

    @Published var enabled: Bool { didSet { save(Key.enabled, enabled) } }
    @Published var strength: Double { didSet { save(Key.strength, min(0.30, max(0, strength))) } }
    @Published var viewportBorder: Bool { didSet { save(Key.viewportBorder, viewportBorder) } }
    @Published var paddingTop: Int { didSet { save(Key.paddingTop, ScreenFrameConfig.clampPadding(paddingTop)) } }
    @Published var paddingRight: Int { didSet { save(Key.paddingRight, ScreenFrameConfig.clampPadding(paddingRight)) } }
    @Published var paddingBottom: Int { didSet { save(Key.paddingBottom, ScreenFrameConfig.clampPadding(paddingBottom)) } }
    @Published var paddingLeft: Int { didSet { save(Key.paddingLeft, ScreenFrameConfig.clampPadding(paddingLeft)) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = ScreenFrameConfig.default
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? fallback.enabled
        strength = defaults.object(forKey: Key.strength) as? Double ?? fallback.strength
        viewportBorder = defaults.object(forKey: Key.viewportBorder) as? Bool ?? fallback.viewportBorder
        paddingTop = ScreenFrameConfig.clampPadding(defaults.integer(forKey: Key.paddingTop))
        paddingRight = ScreenFrameConfig.clampPadding(defaults.integer(forKey: Key.paddingRight))
        paddingBottom = ScreenFrameConfig.clampPadding(defaults.integer(forKey: Key.paddingBottom))
        paddingLeft = ScreenFrameConfig.clampPadding(defaults.integer(forKey: Key.paddingLeft))
        loading = false
    }

    var config: ScreenFrameConfig {
        ScreenFrameConfig(enabled: enabled,
                          strength: min(0.30, max(0, strength)),
                          viewportBorder: viewportBorder,
                          paddingTop: ScreenFrameConfig.clampPadding(paddingTop),
                          paddingRight: ScreenFrameConfig.clampPadding(paddingRight),
                          paddingBottom: ScreenFrameConfig.clampPadding(paddingBottom),
                          paddingLeft: ScreenFrameConfig.clampPadding(paddingLeft))
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        guard !loading else { return }
        ScreenEventHub.notifyChange()
    }
}
