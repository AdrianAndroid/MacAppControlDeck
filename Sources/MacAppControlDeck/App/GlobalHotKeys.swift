import AppKit
import Carbon.HIToolbox
import Combine
import MacShotKit

struct GlobalHotKeyDefinition: Identifiable {
    let id: String
    let hotKeyID: UInt32
    let title: String
    let detail: String
    let defaultCombo: ShortcutCombo
    let action: () -> Void
}

enum GlobalHotKeyStatus: Equatable {
    case registered
    case disabled
    case masterOff
    case suspended
    case duplicate
    case conflict(OSStatus)

    var label: String {
        switch self {
        case .registered: return "已启用"
        case .disabled: return "已关闭"
        case .masterOff: return "全局关闭"
        case .suspended: return "录制中暂停"
        case .duplicate: return "组合重复"
        case .conflict: return "被其他应用占用"
        }
    }

    var isProblem: Bool {
        switch self {
        case .conflict, .duplicate: return true
        default: return false
        }
    }
}

/// Registers system-wide hot keys through Carbon, so they work while other apps are focused.
final class GlobalHotKeys: ObservableObject {
    static let shared = GlobalHotKeys()

    struct BindingSpec: Equatable {
        let id: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
    }

    /// F1 区域截图：沿用 Snipaste 的使用习惯，单独暴露给测试校验键码与修饰键。
    static let captureAreaF1 = BindingSpec(id: 9,
                                           keyCode: UInt32(kVK_F1),
                                           modifiers: 0)

    @Published private(set) var masterEnabled: Bool
    @Published private(set) var settings: [String: GlobalHotKeySetting]
    @Published private(set) var statuses: [String: GlobalHotKeyStatus] = [:]
    @Published private(set) var isSuspended = false

    private(set) var definitions: [GlobalHotKeyDefinition]

    private let store: GlobalHotKeyStore
    private var handler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var pending: [(definition: GlobalHotKeyDefinition, combo: ShortcutCombo)] = []
    private var retryTimer: Timer?

    private static let signature: OSType = 0x4D534B44 // "MSKD"

    init(store: GlobalHotKeyStore = GlobalHotKeyStore()) {
        let definitions = Self.makeDefinitions()
        self.store = store
        self.definitions = definitions
        let preferences = store.load()
        if let preferences, preferences.shortcutsOffByDefault != true {
            // 老版本配置（或重装后第一次启动）统一把全部全局快捷键关掉；
            // 组合保留，用户想用哪个自己打开。
            let migrated = Self.migratedOffByDefault(preferences)
            self.masterEnabled = migrated.masterEnabled
            self.settings = Self.merged(migrated, definitions: definitions)
            store.save(migrated)
        } else {
            self.masterEnabled = preferences?.masterEnabled ?? true
            self.settings = Self.merged(preferences, definitions: definitions)
        }
    }

    // MARK: - 定义

    static func makeDefinitions() -> [GlobalHotKeyDefinition] {
        func combo(_ modifiers: [ShortcutModifier], _ keyCode: UInt16, _ label: String) -> ShortcutCombo {
            ShortcutCombo(modifiers: modifiers, keyCode: keyCode, keyLabel: label)
        }
        return [
            GlobalHotKeyDefinition(
                id: "capture.area", hotKeyID: 1,
                title: "区域截图", detail: "框选屏幕区域并进入标注编辑器",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_X), "X"),
                action: { MainActor.assumeIsolated { MacShotController.shared.captureArea() } }),
            GlobalHotKeyDefinition(
                id: "capture.area.f1", hotKeyID: Self.captureAreaF1.id,
                title: "区域截图（F1）", detail: "独立 F1 入口，可与 ⌘⇧X 分别开关",
                defaultCombo: combo([], UInt16(kVK_F1), "F1"),
                action: { MainActor.assumeIsolated { CaptureModule.shared.captureArea() } }),
            GlobalHotKeyDefinition(
                id: "capture.full", hotKeyID: 2,
                title: "全屏截图", detail: "截取当前显示器全屏",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_F), "F"),
                action: { MainActor.assumeIsolated { MacShotController.shared.captureFullScreen() } }),
            GlobalHotKeyDefinition(
                id: "capture.window", hotKeyID: 3,
                title: "窗口截图", detail: "点选窗口截图",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_W), "W"),
                action: { MainActor.assumeIsolated { MacShotController.shared.captureWindow() } }),
            GlobalHotKeyDefinition(
                id: "capture.scroll", hotKeyID: 4,
                title: "滚动截图", detail: "滚动拼接长截图",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_S), "S"),
                action: { MainActor.assumeIsolated { MacShotController.shared.scrollCapture() } }),
            GlobalHotKeyDefinition(
                id: "capture.record", hotKeyID: 5,
                title: "区域录屏", detail: "开始 MP4 区域录屏",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_R), "R"),
                action: { MainActor.assumeIsolated { MacShotController.shared.startRecording(format: .mp4, target: .area) } }),
            GlobalHotKeyDefinition(
                id: "capture.ocr", hotKeyID: 6,
                title: "区域 OCR", detail: "识别区域文字",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_O), "O"),
                action: { MainActor.assumeIsolated { MacShotController.shared.quickOCRArea() } }),
            GlobalHotKeyDefinition(
                id: "capture.reopen", hotKeyID: 7,
                title: "上次编辑", detail: "重新打开上次截图标注",
                defaultCombo: combo([.command, .shift], UInt16(kVK_ANSI_E), "E"),
                action: { MainActor.assumeIsolated { MacShotController.shared.reopenLastEditSession() } }),
            GlobalHotKeyDefinition(
                id: "sketch.open", hotKeyID: 8,
                title: "打开 UI 草图", detail: "打开离线手绘画板",
                defaultCombo: combo([.control, .option], UInt16(kVK_ANSI_D), "D"),
                action: { MainActor.assumeIsolated { SketchModule.shared.openBoard() } }),
            GlobalHotKeyDefinition(
                id: "pet.toggle", hotKeyID: 10,
                title: "打开桌面宠物", detail: "显示或隐藏桌宠",
                defaultCombo: combo([.control, .option], UInt16(kVK_ANSI_P), "P"),
                action: { MainActor.assumeIsolated { PetModule.shared.toggle() } })
        ]
    }

    /// 已保存的配置只覆盖已知入口，新增入口自动拿到默认组合。
    static func merged(_ preferences: GlobalHotKeyPreferences?,
                       definitions: [GlobalHotKeyDefinition]) -> [String: GlobalHotKeySetting] {
        var merged: [String: GlobalHotKeySetting] = [:]
        for definition in definitions {
            if let saved = preferences?.entries[definition.id] {
                merged[definition.id] = GlobalHotKeySetting(combo: saved.combo.normalized,
                                                            enabled: saved.enabled)
            } else {
                merged[definition.id] = GlobalHotKeySetting(combo: definition.defaultCombo,
                                                            enabled: false)
            }
        }
        return merged
    }

    /// 默认关闭策略：保留各快捷录入项的组合，但把启用状态清零。
    static func migratedOffByDefault(_ preferences: GlobalHotKeyPreferences) -> GlobalHotKeyPreferences {
        var migrated = preferences
        migrated.shortcutsOffByDefault = true
        for (id, setting) in preferences.entries {
            var copy = setting
            copy.enabled = false
            migrated.entries[id] = copy
        }
        return migrated
    }

    // MARK: - 生命周期

    func install() {
        guard handler == nil else {
            apply()
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let manager = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)

        apply()
    }

    func uninstall() {
        teardownRegistrations()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
        statuses.removeAll()
    }

    /// 录制新组合时先全部注销，否则旧热键会吞掉要录制的按键。
    func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        apply()
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        apply()
    }

    // MARK: - 查询

    func definition(for id: String) -> GlobalHotKeyDefinition? {
        definitions.first { $0.id == id }
    }

    func combo(for id: String) -> ShortcutCombo {
        settings[id]?.combo
            ?? definition(for: id)?.defaultCombo
            ?? ShortcutCombo(modifiers: [], keyCode: 0, keyLabel: "")
    }

    func isEnabled(_ id: String) -> Bool {
        settings[id]?.enabled ?? false
    }

    func status(for id: String) -> GlobalHotKeyStatus? {
        statuses[id]
    }

    /// 菜单项展示用：只有当前真正启用的字母组合才回填 key equivalent。
    func menuShortcut(for id: String) -> (keyEquivalent: String, modifiers: NSEvent.ModifierFlags)? {
        guard masterEnabled, !isSuspended, isEnabled(id) else { return nil }
        let combo = combo(for: id)
        guard combo.keyLabel.count == 1 else { return nil }
        return (combo.keyLabel.lowercased(), GlobalHotKeyRules.appKitModifiers(combo.modifiers))
    }

    // MARK: - 修改

    func setMasterEnabled(_ enabled: Bool) {
        guard masterEnabled != enabled else { return }
        masterEnabled = enabled
        persist()
        apply()
    }

    @discardableResult
    func setEnabled(_ id: String, _ enabled: Bool) -> GlobalHotKeyValidation {
        guard var setting = settings[id], setting.enabled != enabled else { return .ok }
        if enabled {
            let result = validate(setting.combo, excluding: id)
            guard result == .ok else { return result }
        }
        setting.enabled = enabled
        settings[id] = setting
        persist()
        apply()
        return .ok
    }

    @discardableResult
    func setCombo(_ id: String, _ combo: ShortcutCombo) -> GlobalHotKeyValidation {
        guard var setting = settings[id] else { return .ok }
        let result = validate(combo, excluding: id)
        guard result == .ok else { return result }
        setting.combo = combo.normalized
        settings[id] = setting
        persist()
        apply()
        return .ok
    }

    @discardableResult
    func reset(_ id: String) -> GlobalHotKeyValidation {
        guard let definition = definition(for: id) else { return .ok }
        let result = validate(definition.defaultCombo, excluding: id)
        guard result == .ok else { return result }
        settings[id] = GlobalHotKeySetting(combo: definition.defaultCombo, enabled: false)
        persist()
        apply()
        return .ok
    }

    func resetAll() {
        for definition in definitions {
            settings[definition.id] = GlobalHotKeySetting(combo: definition.defaultCombo, enabled: false)
        }
        persist()
        apply()
    }

    // MARK: - 注册

    private func apply() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.apply() }
            return
        }
        teardownRegistrations()

        guard handler != nil, masterEnabled, !isSuspended else {
            let state: GlobalHotKeyStatus = masterEnabled ? .suspended : .masterOff
            statuses = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, state) })
            return
        }

        var next: [String: GlobalHotKeyStatus] = [:]
        var used: [ShortcutCombo] = []
        var retry: [(definition: GlobalHotKeyDefinition, combo: ShortcutCombo)] = []
        for definition in definitions {
            guard let setting = settings[definition.id], setting.enabled else {
                next[definition.id] = .disabled
                continue
            }
            let combo = setting.combo.normalized
            guard !used.contains(combo) else {
                next[definition.id] = .duplicate
                continue
            }
            used.append(combo)
            actions[definition.hotKeyID] = definition.action
            let status = register(definition, combo: combo)
            next[definition.id] = status
            if case .conflict = status {
                retry.append((definition, combo))
            }
        }

        statuses = next
        pending = retry
        scheduleRetry()
    }

    private func register(_ definition: GlobalHotKeyDefinition, combo: ShortcutCombo) -> GlobalHotKeyStatus {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: definition.hotKeyID)
        let status = RegisterEventHotKey(UInt32(combo.keyCode),
                                         GlobalHotKeyRules.carbonModifiers(combo.modifiers),
                                         hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
            return .registered
        }
        return .conflict(status)
    }

    /// 热键可能被其他程序（例如已运行的 macshot）占用而注册失败；
    /// 记录失败的绑定并在 2 秒后重试，避免永久失去快捷键。
    private func scheduleRetry() {
        retryTimer?.invalidate()
        retryTimer = nil
        guard !pending.isEmpty else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.retryPending()
        }
    }

    private func retryPending() {
        guard handler != nil, masterEnabled, !isSuspended else {
            retryTimer?.invalidate()
            retryTimer = nil
            return
        }
        var remaining: [(definition: GlobalHotKeyDefinition, combo: ShortcutCombo)] = []
        for item in pending {
            let status = register(item.definition, combo: item.combo)
            statuses[item.definition.id] = status
            if case .conflict = status {
                remaining.append(item)
            }
        }
        pending = remaining
        if pending.isEmpty {
            retryTimer?.invalidate()
            retryTimer = nil
        }
    }

    private func teardownRegistrations() {
        retryTimer?.invalidate()
        retryTimer = nil
        pending.removeAll()
        for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        actions.removeAll()
    }

    // MARK: - 持久化

    private func persist() {
        store.save(GlobalHotKeyPreferences(masterEnabled: masterEnabled,
                                           entries: settings,
                                           shortcutsOffByDefault: true))
    }

    private func validate(_ combo: ShortcutCombo, excluding id: String) -> GlobalHotKeyValidation {
        GlobalHotKeyRules.validate(combo,
                                   excluding: id,
                                   settings: settings,
                                   titles: Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0.title) }))
    }
}
