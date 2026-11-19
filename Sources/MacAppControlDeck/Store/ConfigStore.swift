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
            var order = buttons.sorted { $0.sortOrder < $1.sortOrder }
            guard let index = order.firstIndex(where: { $0.id == id }) else { return false }
            let target = index + offset
            guard order.indices.contains(target) else { return false }
            order.swapAt(index, target)
            buttons = order.enumerated().map { i, item in
                var copy = item
                copy.sortOrder = i
                return copy
            }
            saveButtons()
            return true
        }
    }

    func sortedButtons() -> [ButtonConfig] {
        queue.sync { buttons.sorted { $0.sortOrder < $1.sortOrder } }
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
