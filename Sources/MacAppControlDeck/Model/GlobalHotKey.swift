import AppKit
import Carbon.HIToolbox

/// 单个全局快捷键的持久化状态：组合与是否启用。
struct GlobalHotKeySetting: Codable, Equatable {
    var combo: ShortcutCombo
    var enabled: Bool
}

/// 全局快捷键总配置：一个总开关 + 每个入口自己的组合与开关。
struct GlobalHotKeyPreferences: Codable, Equatable {
    var masterEnabled: Bool
    var entries: [String: GlobalHotKeySetting]
    /// 旧配置没有这个标记；首次读到就按“快捷键默认关闭”迁移一次。
    var shortcutsOffByDefault: Bool? = nil
}

enum GlobalHotKeyValidation: Equatable {
    case ok
    case needsModifier
    case duplicate(String)

    var message: String? {
        switch self {
        case .ok:
            return nil
        case .needsModifier:
            return "全局快捷键至少需要一个修饰键（⌘ ⌃ ⌥ ⇧）；F1–F12 可以单独使用"
        case .duplicate(let title):
            return "与「\(title)」重复，请换一个组合或先关闭那一项"
        }
    }
}

enum GlobalHotKeyRules {
    /// 没有修饰键也能安全使用的功能键：F1–F12。
    static let functionKeyCodes: Set<UInt16> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    static func carbonModifiers(_ modifiers: [ShortcutModifier]) -> UInt32 {
        var value: UInt32 = 0
        for modifier in modifiers {
            switch modifier {
            case .command: value |= UInt32(cmdKey)
            case .control: value |= UInt32(controlKey)
            case .option: value |= UInt32(optionKey)
            case .shift: value |= UInt32(shiftKey)
            case .function: value |= UInt32(1 << 23)
            }
        }
        return value
    }

    static func appKitModifiers(_ modifiers: [ShortcutModifier]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.command)
            case .control: flags.insert(.control)
            case .option: flags.insert(.option)
            case .shift: flags.insert(.shift)
            case .function: flags.insert(.function)
            }
        }
        return flags
    }

    /// 允许「无修饰键」的只有 F1–F12，避免把单个字母注册成全局热键。
    static func needsModifier(_ combo: ShortcutCombo) -> Bool {
        combo.modifiers.isEmpty && !functionKeyCodes.contains(combo.keyCode)
    }

    static func validate(_ combo: ShortcutCombo,
                         excluding id: String,
                         settings: [String: GlobalHotKeySetting],
                         titles: [String: String]) -> GlobalHotKeyValidation {
        if needsModifier(combo) {
            return .needsModifier
        }
        let normalized = combo.normalized
        for (otherID, setting) in settings where otherID != id && setting.enabled {
            if setting.combo.normalized == normalized {
                return .duplicate(titles[otherID] ?? otherID)
            }
        }
        return .ok
    }
}
