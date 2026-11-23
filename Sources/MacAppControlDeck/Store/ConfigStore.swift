import Foundation

final class ConfigStore {
    private let queue = DispatchQueue(label: "deck.configstore")
    private let buttonsURL: URL
    private let devicesURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var buttons: [ButtonConfig] = []
    private(set) var devices: [DeviceRecord] = []

    init(directory: URL? = nil) {
        let base = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        buttonsURL = base.appendingPathComponent("buttons.json")
        devicesURL = base.appendingPathComponent("devices.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let firstLaunch = !FileManager.default.fileExists(atPath: buttonsURL.path)
        load()
        // 仅在真实应用目录（非测试临时目录）执行默认按钮播种，避免污染测试数据
        if directory == nil {
            seedDefaultButtons(firstLaunch: firstLaunch)
        }
    }

    // MARK: - 默认按钮

    /// 首次安装带一组常见应用和快捷启动；老配置只在完全没有快捷按钮时补齐快捷启动，绝不覆盖用户已有按钮。
    private func seedDefaultButtons(firstLaunch: Bool) {
        let seededKey = "config.defaults.seeded.v1"
        let alreadySeeded = UserDefaults.standard.bool(forKey: seededKey)
        let shortcuts = Self.defaultShortcuts()
        var changed = false

        if firstLaunch {
            buttons = Self.defaultApps() + shortcuts
            changed = true
        } else if !alreadySeeded && !buttons.contains(where: { $0.kind == .shortcut }) {
            // 老用户第一次升级时补默认快捷启动；之后即使用户删光也不再自动加回。
            buttons.append(contentsOf: shortcuts)
            changed = true
        }

        let builtinKey = "config.builtin.seeded.v1"
        if !UserDefaults.standard.bool(forKey: builtinKey) {
            if !buttons.contains(where: { $0.kind == .builtin }) {
                let quickMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
                buttons.append(ButtonConfig(id: "builtin.capture.area",
                                            kind: .builtin,
                                            name: "截图（区域）",
                                            sortOrder: quickMax + 1,
                                            builtinAction: "capture.area"))
                changed = true
            }
            UserDefaults.standard.set(true, forKey: builtinKey)
        }

        let calendarKey = "config.builtin.calendar.seeded.v1"
        if !UserDefaults.standard.bool(forKey: calendarKey) {
            if !buttons.contains(where: { $0.builtinAction == "calendar.open" }) {
                let quickMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
                buttons.append(ButtonConfig(id: "builtin.calendar.open",
                                            kind: .builtin,
                                            name: "万年历",
                                            sortOrder: quickMax + 1,
                                            builtinAction: "calendar.open"))
                changed = true
            }
            UserDefaults.standard.set(true, forKey: calendarKey)
        }

        let settingsKey = "config.builtin.settings.seeded.v1"
        if !UserDefaults.standard.bool(forKey: settingsKey) {
            if !buttons.contains(where: { $0.builtinAction == "settings.open" }) {
                let quickMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
                buttons.append(ButtonConfig(id: "builtin.settings.open",
                                            kind: .builtin,
                                            name: "打开设置",
                                            sortOrder: quickMax + 1,
                                            builtinAction: "settings.open"))
                changed = true
            }
            UserDefaults.standard.set(true, forKey: settingsKey)
        }

        let hotkeysKey = "config.builtin.hotkeys.seeded.v1"
        if !UserDefaults.standard.bool(forKey: hotkeysKey) {
            if !buttons.contains(where: { $0.builtinAction == "hotkeys.open" }) {
                let quickMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
                buttons.append(ButtonConfig(id: "builtin.hotkeys.open",
                                            kind: .builtin,
                                            name: "快捷键设置",
                                            sortOrder: quickMax + 1,
                                            builtinAction: "hotkeys.open"))
                changed = true
            }
            UserDefaults.standard.set(true, forKey: hotkeysKey)
        }

        UserDefaults.standard.set(true, forKey: seededKey)
        if changed { saveButtons() }
    }

    private static func defaultApps() -> [ButtonConfig] {
        let candidates: [(String, String, String)] = [
            ("访达", "com.apple.finder", "/System/Library/CoreServices/Finder.app"),
            ("Safari", "com.apple.Safari", "/Applications/Safari.app"),
            ("终端", "com.apple.Terminal", "/System/Applications/Utilities/Terminal.app"),
            ("Google Chrome", "com.google.Chrome", "/Applications/Google Chrome.app"),
            ("Visual Studio Code", "com.microsoft.VSCode", "/Applications/Visual Studio Code.app")
        ]
        var result: [ButtonConfig] = []
        for (name, bundleID, path) in candidates {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            result.append(ButtonConfig(id: "default.app.\(bundleID)",
                                       kind: .app,
                                       name: name,
                                       bundleID: bundleID,
                                       appPath: path,
                                       sortOrder: result.count))
            if result.count == 4 { break }
        }
        return result
    }

    private static func defaultShortcuts() -> [ButtonConfig] {
        let definitions: [(String, String, [ShortcutModifier], UInt16)] = [
            ("显示桌面", "default.shortcut.showDesktop", [], 103),
            ("调度中心", "default.shortcut.missionControl", [.control], 126),
            ("切换应用", "default.shortcut.switchApp", [.command], 48),
            ("复制选中", "default.shortcut.copy", [.command], 8)
        ]
        return definitions.enumerated().map { index, item in
            let (name, id, modifiers, keyCode) = item
            let label: String
            switch keyCode {
            case 103: label = "F11"
            case 126: label = "↑"
            case 48: label = "Tab"
            case 8: label = "C"
            default: label = "\(keyCode)"
            }
            return ButtonConfig(id: id,
                                kind: .shortcut,
                                name: name,
                                sortOrder: index,
                                shortcut: ShortcutCombo(modifiers: modifiers,
                                                        keyCode: keyCode,
                                                        keyLabel: label).normalized)
        }
    }

    static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support.appendingPathComponent("MacAppControlDeck", isDirectory: true)
    }

    private func load() {
        buttons = (try? decode([ButtonConfig].self, from: buttonsURL)) ?? []
        devices = (try? decode([DeviceRecord].self, from: devicesURL)) ?? []
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".tmp-" + UUID().uuidString)
        try data.write(to: tmp)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }

    // MARK: - Buttons

    @discardableResult
    func addButton(name: String, bundleID: String, appPath: String) -> ButtonConfig {
        queue.sync {
            let sorted = buttons.map { $0.sortOrder }.max() ?? -1
            let config = ButtonConfig(id: UUID().uuidString,
                                      name: name,
                                      bundleID: bundleID,
                                      appPath: appPath,
                                      sortOrder: sorted + 1)
            buttons.append(config)
            saveButtons()
            return config
        }
    }

    @discardableResult
    func addShortcutButton(name: String, combo: ShortcutCombo) -> ButtonConfig {
        queue.sync {
            let groupMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
            let config = ButtonConfig(id: UUID().uuidString,
                                      kind: .shortcut,
                                      name: name,
                                      sortOrder: groupMax + 1,
                                      shortcut: combo.normalized)
            buttons.append(config)
            saveButtons()
            return config
        }
    }

    @discardableResult
    func addBuiltinButton(name: String, action: String) -> ButtonConfig {
        queue.sync {
            let groupMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
            let config = ButtonConfig(id: UUID().uuidString,
                                      kind: .builtin,
                                      name: name,
                                      sortOrder: groupMax + 1,
                                      builtinAction: action)
            buttons.append(config)
            saveButtons()
            return config
        }
    }

    @discardableResult
    func addCommandButton(name: String, appPath: String, bundleID: String, arguments: [String]) -> ButtonConfig {
        queue.sync {
            let groupMax = buttons.filter { Self.kindRank($0.kind) == 1 }.map { $0.sortOrder }.max() ?? -1
            let config = ButtonConfig(id: UUID().uuidString,
                                      kind: .command,
                                      name: name,
                                      bundleID: bundleID,
                                      appPath: appPath,
                                      sortOrder: groupMax + 1,
                                      commandArguments: arguments)
            buttons.append(config)
            saveButtons()
            return config
        }
    }

    @discardableResult
    func updateCommand(id: String, name: String?, appPath: String?, bundleID: String?, arguments: [String]?) -> Bool {
        queue.sync {
            guard let index = buttons.firstIndex(where: { $0.id == id }), buttons[index].kind == .command else {
                return false
            }
            if let name, !name.isEmpty { buttons[index].name = name }
            if let appPath { buttons[index].appPath = appPath }
            if let bundleID { buttons[index].bundleID = bundleID }
            if let arguments { buttons[index].commandArguments = arguments }
            saveButtons()
            return true
        }
    }

    @discardableResult
    func updateShortcut(id: String, name: String?, combo: ShortcutCombo?) -> Bool {
        queue.sync {
            guard let index = buttons.firstIndex(where: { $0.id == id }), buttons[index].kind == .shortcut else {
                return false
            }
            if let name, !name.isEmpty { buttons[index].name = name }
            if let combo { buttons[index].shortcut = combo.normalized }
            saveButtons()
            return true
        }
    }

    @discardableResult
    func renameButton(id: String, to newName: String) -> Bool {
        queue.sync {
            guard let index = buttons.firstIndex(where: { $0.id == id }) else { return false }
            buttons[index].name = newName
            saveButtons()
            return true
        }
    }

    @discardableResult
    func deleteButton(id: String) -> Bool {
        queue.sync {
            guard let index = buttons.firstIndex(where: { $0.id == id }) else { return false }
            buttons.remove(at: index)
            saveButtons()
            return true
        }
    }

    @discardableResult
    func moveButton(id: String, offset: Int) -> Bool {
        queue.sync {
            guard let moving = buttons.first(where: { $0.id == id }) else { return false }
            let rank = Self.kindRank(moving.kind)
            var group = buttons.filter { Self.kindRank($0.kind) == rank }.sorted { $0.sortOrder < $1.sortOrder }
            guard let index = group.firstIndex(where: { $0.id == id }) else { return false }
            let target = index + offset
            guard group.indices.contains(target) else { return false }
            group.swapAt(index, target)
            for (i, item) in group.enumerated() {
                if let global = buttons.firstIndex(where: { $0.id == item.id }) {
                    buttons[global].sortOrder = i
                }
            }
            saveButtons()
            return true
        }
    }

    func sortedButtons() -> [ButtonConfig] {
        queue.sync {
            buttons.sorted {
                let rank = Self.kindRank($0.kind), otherRank = Self.kindRank($1.kind)
                if rank != otherRank { return rank < otherRank }
                return $0.sortOrder < $1.sortOrder
            }
        }
    }

    /// 排序分组：应用一组，快捷操作与命令共用一个"快捷"组（面板上也显示在一起）。
    static func kindRank(_ kind: ButtonKind) -> Int {
        kind == .app ? 0 : 1
    }

    func buttons(kind: ButtonKind) -> [ButtonConfig] {
        sortedButtons().filter { $0.kind == kind }
    }

    @discardableResult
    func moveButton(id: String, toIndex: Int) -> Bool {
        queue.sync {
            guard let moving = buttons.first(where: { $0.id == id }) else { return false }
            let rank = Self.kindRank(moving.kind)
            var group = buttons.filter { Self.kindRank($0.kind) == rank }.sorted { $0.sortOrder < $1.sortOrder }
            group.removeAll { $0.id == id }
            let clamped = min(max(0, toIndex), group.count)
            group.insert(moving, at: clamped)
            for (index, item) in group.enumerated() {
                if let global = buttons.firstIndex(where: { $0.id == item.id }) {
                    buttons[global].sortOrder = index
                }
            }
            saveButtons()
            return true
        }
    }

    func button(id: String) -> ButtonConfig? {
        queue.sync { buttons.first { $0.id == id } }
    }

    private func saveButtons() {
        if let data = try? encoder.encode(buttons) {
            try? atomicWrite(data, to: buttonsURL)
        }
    }

    // MARK: - Devices

    @discardableResult
    func addDevice(token: String, name: String) -> DeviceRecord {
        queue.sync {
            let record = DeviceRecord(token: token, name: name, pairedAt: Date())
            devices.removeAll { $0.token == token || $0.name == name }
            devices.append(record)
            saveDevices()
            return record
        }
    }

    func device(token: String) -> DeviceRecord? {
        queue.sync { devices.first { $0.token == token } }
    }

    @discardableResult
    func revokeDevice(token: String) -> Bool {
        queue.sync {
            let before = devices.count
            devices.removeAll { $0.token == token }
            guard devices.count < before else { return false }
            saveDevices()
            return true
        }
    }

    func saveDevices() {
        if let data = try? encoder.encode(devices) {
            try? atomicWrite(data, to: devicesURL)
        }
    }
}
