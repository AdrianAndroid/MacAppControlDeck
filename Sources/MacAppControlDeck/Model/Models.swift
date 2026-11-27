import Foundation

enum ButtonKind: String, Codable, CaseIterable {
    case app
    case shortcut
    case command
    case builtin
}

enum ShortcutModifier: String, Codable, CaseIterable, Comparable {
    case function
    case control
    case option
    case shift
    case command

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .function: return "fn"
        }
    }

    static func < (lhs: ShortcutModifier, rhs: ShortcutModifier) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

struct ShortcutCombo: Codable, Equatable {
    var modifiers: [ShortcutModifier]
    var keyCode: UInt16
    var keyLabel: String

    var symbol: String {
        modifiers.sorted().map(\.symbol).joined() + keyLabel
    }

    var normalized: ShortcutCombo {
        var copy = self
        copy.modifiers = Array(Set(modifiers)).sorted()
        return copy
    }
}

struct ButtonConfig: Codable, Identifiable, Equatable {
    var id: String
    var kind: ButtonKind
    var name: String
    var bundleID: String
    var appPath: String
    var sortOrder: Int
    var shortcut: ShortcutCombo?
    var commandArguments: [String]?
    var builtinAction: String?

    init(id: String,
         kind: ButtonKind = .app,
         name: String,
         bundleID: String = "",
         appPath: String = "",
         sortOrder: Int,
         shortcut: ShortcutCombo? = nil,
         commandArguments: [String]? = nil,
         builtinAction: String? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.bundleID = bundleID
        self.appPath = appPath
        self.sortOrder = sortOrder
        self.shortcut = shortcut
        self.commandArguments = commandArguments
        self.builtinAction = builtinAction
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = (try? container.decode(ButtonKind.self, forKey: .kind)) ?? .app
        name = try container.decode(String.self, forKey: .name)
        bundleID = (try? container.decode(String.self, forKey: .bundleID)) ?? ""
        appPath = (try? container.decode(String.self, forKey: .appPath)) ?? ""
        sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
        shortcut = (try? container.decodeIfPresent(ShortcutCombo.self, forKey: .shortcut))?.normalized
        commandArguments = try? container.decodeIfPresent([String].self, forKey: .commandArguments)
        builtinAction = try? container.decodeIfPresent(String.self, forKey: .builtinAction)
    }

    var displaySymbol: String? {
        guard kind == .shortcut, let shortcut else { return nil }
        return shortcut.symbol
    }
}

struct DeviceRecord: Codable, Identifiable, Equatable {
    var token: String
    var name: String
    var pairedAt: Date
    var lastSeenAt: Date?

    var id: String { token }
}

/// 只读副屏的浏览器登记。没有 token，不能执行任何操作，仅用于「设备」页展示。
struct ScreenClientRecord: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var firstSeenAt: Date
    var lastSeenAt: Date

    static func displayName(userAgent: String) -> String {
        let ua = userAgent.lowercased()
        guard !ua.isEmpty else { return "未知设备" }

        let device: String
        if ua.contains("iphone") { device = "iPhone" }
        else if ua.contains("ipad") { device = "iPad" }
        else if ua.contains("android") { device = "Android" }
        else if ua.contains("macintosh") || ua.contains("mac os x") { device = "Mac" }
        else if ua.contains("windows") { device = "Windows" }
        else { device = "设备" }

        let browser: String
        if ua.contains("edgios") || ua.contains("edg/") { browser = "Edge" }
        else if ua.contains("crios") || ua.contains("chrome/") { browser = "Chrome" }
        else if ua.contains("fxios") || ua.contains("firefox/") { browser = "Firefox" }
        else if ua.contains("safari/") { browser = "Safari" }
        else { browser = "浏览器" }

        return "\(device) · \(browser)"
    }
}

struct InstalledApp: Identifiable, Equatable, Hashable {
    var name: String
    var bundleID: String
    var path: String

    var id: String { bundleID }
}

enum ActivateStatus: String, Codable {
    case launched
    case activated
    case sent
    case unconfirmed
    case appNotFound = "app-not-found"
    case activationFailed = "activation-failed"
    case buttonNotFound = "button-not-found"
}
