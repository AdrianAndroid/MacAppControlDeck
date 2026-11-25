import Combine
import Foundation

/// 副屏显示设置：字号尺寸、桌宠模式/宠物/随机间隔、屏幕常亮。
/// 全部由 Mac 端统一配置并下发给副屏，副屏页面本身不再提供设置入口。
struct ScreenDisplayConfig: Codable, Equatable {
    var size: String
    var petMode: String
    var petId: String
    var petInterval: Int
    var keepAwake: Bool
    /// 递增计数：PC 端点「立即换一只」时 +1，副屏据此触发换宠。
    var petSwitchNonce: Int

    static let `default` = ScreenDisplayConfig(size: "m",
                                                petMode: "fixed",
                                                petId: "cat",
                                                petInterval: 60,
                                                keepAwake: true,
                                                petSwitchNonce: 0)

    static let validSizes = ["s", "m", "l"]
    static let validPetIDs = ["cat", "dog", "robot"]
    static let validIntervals = [30, 60, 300, 900]

    var normalized: ScreenDisplayConfig {
        var value = self
        if !Self.validSizes.contains(value.size) { value.size = "m" }
        if value.petMode != "random" { value.petMode = "fixed" }
        if !Self.validPetIDs.contains(value.petId) { value.petId = "cat" }
        if !Self.validIntervals.contains(value.petInterval) { value.petInterval = 60 }
        return value
    }
}

final class ScreenDisplaySettings: ObservableObject {
    static let shared = ScreenDisplaySettings()

    private enum Key {
        static let size = "screen.display.size"
        static let petMode = "screen.display.pet.mode"
        static let petId = "screen.display.pet.id"
        static let petInterval = "screen.display.pet.interval"
        static let keepAwake = "screen.display.keepAwake"
        static let petSwitchNonce = "screen.display.petSwitchNonce"
    }

    private let defaults: UserDefaults
    private var loading = true

    @Published var size: String { didSet { save(Key.size, size) } }
    @Published var petMode: String { didSet { save(Key.petMode, petMode) } }
    @Published var petId: String { didSet { save(Key.petId, petId) } }
    @Published var petInterval: Int { didSet { save(Key.petInterval, petInterval) } }
    @Published var keepAwake: Bool { didSet { save(Key.keepAwake, keepAwake) } }
    @Published var petSwitchNonce: Int { didSet { save(Key.petSwitchNonce, petSwitchNonce) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = ScreenDisplayConfig.default
        size = defaults.string(forKey: Key.size) ?? fallback.size
        petMode = defaults.string(forKey: Key.petMode) ?? fallback.petMode
        petId = defaults.string(forKey: Key.petId) ?? fallback.petId
        let storedInterval = defaults.integer(forKey: Key.petInterval)
        petInterval = storedInterval == 0 ? fallback.petInterval : storedInterval
        keepAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? fallback.keepAwake
        petSwitchNonce = defaults.integer(forKey: Key.petSwitchNonce)
        loading = false
    }

    var config: ScreenDisplayConfig {
        ScreenDisplayConfig(size: size,
                            petMode: petMode,
                            petId: petId,
                            petInterval: petInterval,
                            keepAwake: keepAwake,
                            petSwitchNonce: petSwitchNonce).normalized
    }

    /// PC 端「立即换一只」：固定模式下直接切到下一只；随机模式下递增 nonce 让副屏换一只。
    func requestPetSwitch() {
        if petMode == "fixed", let index = ScreenDisplayConfig.validPetIDs.firstIndex(of: petId) {
            petId = ScreenDisplayConfig.validPetIDs[(index + 1) % ScreenDisplayConfig.validPetIDs.count]
        }
        petSwitchNonce += 1
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        guard !loading else { return }
        ScreenEventHub.notifyChange()
    }
}
