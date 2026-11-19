import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct ShortcutInjectionResult {
    var sent: Bool
    var errorCode: String?
    var message: String
}

protocol ShortcutInjecting {
    func inject(_ combo: ShortcutCombo) -> ShortcutInjectionResult
}

struct ShortcutPreset: Identifiable, Equatable {
    var id: String
    var name: String
    var combo: ShortcutCombo

    var symbol: String { combo.symbol }
}

enum ShortcutPresets {
    static let all: [ShortcutPreset] = [
        preset("desktop-left", "桌面左", [.control], 123, "←"),
        preset("desktop-right", "桌面右", [.control], 124, "→"),
        preset("copy", "复制", [.command], 8, "C"),
        preset("paste", "粘贴", [.command], 9, "V"),
        preset("select-all", "全选", [.command], 0, "A"),
        preset("undo", "撤销", [.command], 6, "Z"),
        preset("enter", "回车", [], 36, "↩"),
        preset("escape", "Esc", [], 53, "⎋"),
        preset("f1", "F1", [], 122, "F1"),
        preset("f2", "F2", [], 120, "F2"),
        preset("f3", "F3", [], 99, "F3"),
        preset("f4", "F4", [], 118, "F4"),
        preset("f5", "F5", [], 96, "F5"),
        preset("f6", "F6", [], 97, "F6"),
        preset("f7", "F7", [], 98, "F7"),
        preset("f8", "F8", [], 100, "F8"),
        preset("f9", "F9", [], 101, "F9"),
        preset("f10", "F10", [], 109, "F10"),
        preset("f11", "F11", [], 103, "F11"),
        preset("f12", "F12", [], 111, "F12"),
    ]

    private static func preset(_ id: String, _ name: String,
                               _ modifiers: [ShortcutModifier],
                               _ keyCode: UInt16, _ label: String) -> ShortcutPreset {
        ShortcutPreset(id: id, name: name,
                       combo: ShortcutCombo(modifiers: modifiers, keyCode: keyCode, keyLabel: label))
    }
}

struct KeyInjector: ShortcutInjecting {
    private let logger: (String) -> Void

    init(log: @escaping (String) -> Void = { _ in }) {
        self.logger = log
    }

    func inject(_ combo: ShortcutCombo) -> ShortcutInjectionResult {
        // 桌面左右切换走 System Events：WindowServer 的系统快捷键
        // 会忽略本进程直接注入的按键。
        if Self.isSpaceSwitch(combo) {
            return Self.runSystemEventsKey(combo, logger: logger)
        }
        guard AXIsProcessTrusted() else {
            logger("注入失败：未授权辅助功能")
            return ShortcutInjectionResult(sent: false,
                                           errorCode: "accessibility-required",
                                           message: "需要辅助功能权限：系统设置 → 隐私与安全性 → 辅助功能 授权本程序")
        }
        guard !IsSecureEventInputEnabled() else {
            logger("注入失败：安全输入模式")
            return ShortcutInjectionResult(sent: false,
                                           errorCode: "secure-input",
                                           message: "当前处于安全输入状态（如密码输入框），快捷键未生效")
        }
        guard !combo.keyLabel.isEmpty else {
            logger("注入失败：组合缺少主键")
            return ShortcutInjectionResult(sent: false,
                                           errorCode: "bad-button-config",
                                           message: "快捷操作配置不完整（缺少主键），请在 Mac 端重新编辑")
        }

        // 优先通过随包 CLI 助手投递：Snipaste 等全局热键应用会忽略
        // 直接由 GUI 进程 post 的事件，而 CLI 子进程的注入能被正常识别。
        if let sender = Self.helperURL(), Self.runHelper(sender, combo: combo) {
            logger("已通过助手注入 \(combo.symbol)")
            return ShortcutInjectionResult(sent: true, errorCode: nil, message: "已发送快捷键")
        }
        logger("助手不可用，回退进程内注入")

        let flags = Self.flags(for: combo.modifiers)
        let keyCode = CGKeyCode(combo.keyCode)
        // 在主线程投递：WindowServer 的全局热键匹配对投递线程敏感，
        // 后台网络线程直接 post 时，Snipaste 等全局热键应用收不到事件。
        func postAll() {
            for keyDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil,
                                          virtualKey: keyCode,
                                          keyDown: keyDown) else { continue }
                event.flags = flags
                event.post(tap: .cghidEventTap)
                usleep(60_000)
            }
        }
        if Thread.isMainThread {
            postAll()
        } else {
            DispatchQueue.main.sync { postAll() }
        }
        logger("已注入 \(combo.symbol)")
        return ShortcutInjectionResult(sent: true, errorCode: nil, message: "已发送快捷键")
    }

    static func isSpaceSwitch(_ combo: ShortcutCombo) -> Bool {
        Set(combo.modifiers) == [.control] && (combo.keyCode == 123 || combo.keyCode == 124)
    }

    static func runSystemEventsKey(_ combo: ShortcutCombo, logger: (String) -> Void) -> ShortcutInjectionResult {
        let direction = combo.keyCode == 123 ? "left" : "right"
        let script = "tell application \"System Events\" to key code \(combo.keyCode) using control down"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        var errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger("System Events 调用失败: \(error.localizedDescription)")
            return ShortcutInjectionResult(sent: false, errorCode: "automation-failed",
                                           message: "无法调用 System Events：\(error.localizedDescription)")
        }
        if process.terminationStatus == 0 {
            logger("已通过 System Events 切换空间 (\(direction))")
            return ShortcutInjectionResult(sent: true, errorCode: nil, message: "已切换到相邻桌面")
        }
        let errText = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        logger("System Events 失败: \(errText)")
        if errText.contains("-1743") || errText.lowercased().contains("not allowed") {
            return ShortcutInjectionResult(sent: false, errorCode: "automation-required",
                                           message: "需要「自动化」权限：系统设置 → 隐私与安全性 → 自动化 → 允许 MacAppControlDeck 控制 System Events")
        }
        return ShortcutInjectionResult(sent: false, errorCode: "automation-failed",
                                       message: "桌面切换失败：\(errText.isEmpty ? "System Events 返回错误" : errText)")
    }

    static func helperURL() -> URL? {
        guard let executable = Bundle.main.executableURL else { return nil }
        let url = executable.deletingLastPathComponent().appendingPathComponent("KeySender")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    static func modifierMask(_ modifiers: [ShortcutModifier]) -> UInt64 {
        var mask: UInt64 = 0
        if modifiers.contains(.command) { mask |= 1 }
        if modifiers.contains(.control) { mask |= 2 }
        if modifiers.contains(.option) { mask |= 4 }
        if modifiers.contains(.shift) { mask |= 8 }
        if modifiers.contains(.function) { mask |= 16 }
        return mask
    }

    static func runHelper(_ url: URL, combo: ShortcutCombo) -> Bool {
        let process = Process()
        process.executableURL = url
        process.arguments = [String(combo.keyCode), String(modifierMask(combo.modifiers))]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func flags(for modifiers: [ShortcutModifier]) -> CGEventFlags {
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .control: flags.insert(.maskControl)
            case .option: flags.insert(.maskAlternate)
            case .shift: flags.insert(.maskShift)
            case .function: flags.insert(.maskSecondaryFn)
            }
        }
        return flags
    }
}

enum ShortcutKeys {
    static let all: [(keyCode: UInt16, label: String)] = {
        var keys: [(UInt16, String)] = []
        let letters: [(UInt16, String)] = [
            (0, "A"), (11, "B"), (8, "C"), (2, "D"), (14, "E"), (3, "F"), (5, "G"),
            (4, "H"), (34, "I"), (38, "J"), (40, "K"), (37, "L"), (46, "M"), (45, "N"),
            (31, "O"), (35, "P"), (12, "Q"), (15, "R"), (1, "S"), (17, "T"), (32, "U"),
            (9, "V"), (13, "W"), (7, "X"), (16, "Y"), (6, "Z"),
        ]
        let digits: [(UInt16, String)] = [
            (29, "0"), (18, "1"), (19, "2"), (20, "3"), (21, "4"),
            (23, "5"), (22, "6"), (26, "7"), (28, "8"), (25, "9"),
        ]
        let others: [(UInt16, String)] = [
            (36, "↩"), (48, "⇥"), (49, "␣"), (51, "⌫"), (53, "⎋"),
            (123, "←"), (124, "→"), (125, "↓"), (126, "↑"),
            (122, "F1"), (120, "F2"), (99, "F3"), (118, "F4"), (96, "F5"), (97, "F6"),
            (98, "F7"), (100, "F8"), (101, "F9"), (109, "F10"), (103, "F11"), (111, "F12"),
        ]
        keys.append(contentsOf: letters)
        keys.append(contentsOf: digits)
        keys.append(contentsOf: others)
        return keys
    }()

    static func label(for keyCode: UInt16) -> String? {
        all.first { $0.keyCode == keyCode }?.label
    }
}
