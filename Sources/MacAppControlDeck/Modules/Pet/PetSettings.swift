import Combine
import Foundation

enum PetKind: String, CaseIterable, Identifiable {
    case bongoCat, keyCat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bongoCat: return "BongoCat"
        case .keyCat: return "KeyCat"
        }
    }
    var detail: String {
        switch self {
        case .bongoCat: return "白猫与键盘鼠标，响应键鼠和光标。"
        case .keyCat: return "黑猫与键盘，响应输入与光标。"
        }
    }
}

/// 桌宠独立偏好，只使用 pet. 前缀。
@MainActor
final class PetSettings: ObservableObject {
    static let shared = PetSettings()

    private enum Key {
        static let kind = "pet.kind"
        static let visible = "pet.visible"
        static let skin = "pet.skin"
        static let size = "pet.size"
        static let keyboardTheme = "pet.keyboardTheme"
        static let paused = "pet.paused"
        static let locked = "pet.locked"
        static let clickThrough = "pet.clickThrough"
        static let randomSkin = "pet.randomSkin"
        static let sleepMinutes = "pet.sleepMinutes"
        static let followMouse = "pet.followMouse"
        static let hoverPetting = "pet.hoverPetting"
        static let allowFullScreen = "pet.allowFullScreen"
        static let hideDuringCapture = "pet.hideDuringCapture"
        static let firstRunDone = "pet.firstRunDone"
        static let live2d = "pet.live2d"
        static let live2dModel = "pet.live2d.model"
        static let live2dTint = "pet.live2d.tint"
        static let positionPrefix = "pet.position."
    }

    private let defaults: UserDefaults

    @Published var kind: PetKind {
        didSet { defaults.set(kind.rawValue, forKey: Key.kind) }
    }
    @Published var visible: Bool {
        didSet { defaults.set(visible, forKey: Key.visible) }
    }
    @Published var skinID: String {
        didSet { defaults.set(skinID, forKey: Key.skin) }
    }
    @Published var size: PetSize {
        didSet { defaults.set(size.rawValue, forKey: Key.size) }
    }
    @Published var keyboardTheme: PetKeyboardTheme {
        didSet { defaults.set(keyboardTheme.rawValue, forKey: Key.keyboardTheme) }
    }
    @Published var paused: Bool {
        didSet { defaults.set(paused, forKey: Key.paused) }
    }
    @Published var locked: Bool {
        didSet { defaults.set(locked, forKey: Key.locked) }
    }
    @Published var clickThrough: Bool {
        didSet { defaults.set(clickThrough, forKey: Key.clickThrough) }
    }
    @Published var randomSkinOnLaunch: Bool {
        didSet { defaults.set(randomSkinOnLaunch, forKey: Key.randomSkin) }
    }
    @Published var sleepMinutes: Int {
        didSet { defaults.set(sleepMinutes, forKey: Key.sleepMinutes) }
    }
    @Published var followMouse: Bool {
        didSet { defaults.set(followMouse, forKey: Key.followMouse) }
    }
    @Published var hoverPetting: Bool {
        didSet { defaults.set(hoverPetting, forKey: Key.hoverPetting) }
    }
    @Published var allowFullScreen: Bool {
        didSet { defaults.set(allowFullScreen, forKey: Key.allowFullScreen) }
    }
    @Published var hideDuringCapture: Bool {
        didSet { defaults.set(hideDuringCapture, forKey: Key.hideDuringCapture) }
    }
    @Published var live2DMode: Bool {
        didSet { defaults.set(live2DMode, forKey: Key.live2d) }
    }

    /// Live2D 皮肤：同一套骨架，只换模型/调色
    @Published var live2dModel: String {
        didSet { defaults.set(live2dModel, forKey: Key.live2dModel) }
    }

    @Published var live2dTint: String {
        didSet { defaults.set(live2dTint, forKey: Key.live2dTint) }
    }

    @Published var firstRunDone: Bool {
        didSet { defaults.set(firstRunDone, forKey: Key.firstRunDone) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        kind = PetKind(rawValue: defaults.string(forKey: Key.kind) ?? "") ?? .bongoCat
        visible = defaults.object(forKey: Key.visible) as? Bool ?? false
        skinID = defaults.string(forKey: Key.skin) ?? PetSkinCatalog.defaultID
        size = PetSize(rawValue: defaults.string(forKey: Key.size) ?? "") ?? .medium
        keyboardTheme = PetKeyboardTheme(rawValue: defaults.string(forKey: Key.keyboardTheme) ?? "") ?? .cream
        paused = defaults.bool(forKey: Key.paused)
        locked = defaults.bool(forKey: Key.locked)
        clickThrough = defaults.bool(forKey: Key.clickThrough)
        randomSkinOnLaunch = defaults.bool(forKey: Key.randomSkin)
        let sleep = defaults.object(forKey: Key.sleepMinutes) as? Int ?? 5
        sleepMinutes = [0, 5, 10, 20].contains(sleep) ? sleep : 5
        followMouse = defaults.object(forKey: Key.followMouse) as? Bool ?? true
        hoverPetting = defaults.object(forKey: Key.hoverPetting) as? Bool ?? true
        allowFullScreen = defaults.bool(forKey: Key.allowFullScreen)
        hideDuringCapture = defaults.object(forKey: Key.hideDuringCapture) as? Bool ?? true
        firstRunDone = defaults.bool(forKey: Key.firstRunDone)
        live2DMode = true
        live2dModel = "bongocat"
        live2dTint = defaults.string(forKey: Key.live2dTint) ?? "ffffff"
        if !PetSkinCatalog.all.contains(where: { $0.id == skinID }) {
            skinID = PetSkinCatalog.defaultID
        }
    }

    var skin: PetSkin {
        PetSkinCatalog.skin(id: skinID) ?? PetSkinCatalog.defaultSkin
    }

    func chooseSkin(_ id: String) {
        guard PetSkinCatalog.skin(id: id) != nil else { return }
        skinID = id
        keyboardTheme = skin.defaultKeyboardTheme
    }

    func resetPosition() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Key.positionPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    func savedPosition(for screenID: String) -> CGPoint? {
        guard let values = defaults.array(forKey: Key.positionPrefix + screenID) as? [Double],
              values.count == 2 else { return nil }
        return CGPoint(x: values[0], y: values[1])
    }

    func savePosition(_ point: CGPoint, for screenID: String) {
        defaults.set([Double(point.x), Double(point.y)], forKey: Key.positionPrefix + screenID)
    }
}
