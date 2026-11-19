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
        load()
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
            let groupMax = buttons.filter { $0.kind == .shortcut }.map { $0.sortOrder }.max() ?? -1
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
    func addCommandButton(name: String, appPath: String, bundleID: String, arguments: [String]) -> ButtonConfig {
        queue.sync {
            let groupMax = buttons.filter { $0.kind == .command }.map { $0.sortOrder }.max() ?? -1
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
            var group = buttons.filter { $0.kind == moving.kind }.sorted { $0.sortOrder < $1.sortOrder }
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
                if $0.kind != $1.kind { return $0.kind == .app }
                return $0.sortOrder < $1.sortOrder
            }
        }
    }

    func buttons(kind: ButtonKind) -> [ButtonConfig] {
        sortedButtons().filter { $0.kind == kind }
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
