import XCTest
@testable import MacAppControlDeck

final class ConfigStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_buttonsPersistAcrossRestart() {
        let store = ConfigStore(directory: directory)
        store.addButton(name: "Safari", bundleID: "com.apple.Safari", appPath: "/Applications/Safari.app")
        store.addButton(name: "备忘录", bundleID: "com.apple.Notes", appPath: "/System/Applications/Notes.app")

        let reloaded = ConfigStore(directory: directory)
        XCTAssertEqual(reloaded.sortedButtons().map(\.name), ["Safari", "备忘录"])
        XCTAssertEqual(reloaded.sortedButtons().map(\.sortOrder), [0, 1])
    }

    func test_renameDeleteMoveButton() {
        let store = ConfigStore(directory: directory)
        let a = store.addButton(name: "A", bundleID: "a", appPath: "/a.app")
        let b = store.addButton(name: "B", bundleID: "b", appPath: "/b.app")

        XCTAssertTrue(store.renameButton(id: a.id, to: "A2"))
        XCTAssertFalse(store.renameButton(id: "missing", to: "X"))
        XCTAssertTrue(store.moveButton(id: b.id, offset: -1))
        XCTAssertEqual(store.sortedButtons().map(\.name), ["B", "A2"])
        XCTAssertTrue(store.deleteButton(id: a.id))
        XCTAssertFalse(store.deleteButton(id: a.id))
        XCTAssertEqual(store.sortedButtons().count, 1)
    }

    func test_deviceTokenLifecycle() {
        let store = ConfigStore(directory: directory)
        let token = PairingManager.generateToken()
        _ = store.addDevice(token: token, name: "iPhone")

        XCTAssertNotNil(store.device(token: token))
        XCTAssertTrue(store.revokeDevice(token: token))
        XCTAssertNil(store.device(token: token), "撤销后旧凭证必须失效")
        XCTAssertFalse(store.revokeDevice(token: token))
    }

    func test_devicePersistsAcrossRestart() {
        let store = ConfigStore(directory: directory)
        let token = PairingManager.generateToken()
        _ = store.addDevice(token: token, name: "iPad")
        let reloaded = ConfigStore(directory: directory)
        XCTAssertEqual(reloaded.device(token: token)?.name, "iPad")
    }

    func test_deviceLastSeenUpdates() {
        let store = ConfigStore(directory: directory)
        let token = PairingManager.generateToken()
        _ = store.addDevice(token: token, name: "iPhone")
        let seen = Date(timeIntervalSince1970: 1_800_000_000)
        store.touchDevice(token: token, now: seen)
        XCTAssertEqual(store.device(token: token)?.lastSeenAt, seen)
        let reloaded = ConfigStore(directory: directory)
        XCTAssertEqual(reloaded.device(token: token)?.lastSeenAt, seen)
    }

    func test_screenClientPersistsAndKeepsFirstSeen() {
        let store = ConfigStore(directory: directory)
        let first = Date(timeIntervalSince1970: 1_800_000_000)
        let later = first.addingTimeInterval(60)
        _ = store.touchScreenClient(id: "screen-abc12345", name: "iPhone · Safari", now: first)
        let updated = store.touchScreenClient(id: "screen-abc12345", name: "iPhone · Safari", now: later)
        XCTAssertEqual(updated.firstSeenAt, first)
        XCTAssertEqual(updated.lastSeenAt, later)

        let reloaded = ConfigStore(directory: directory)
        XCTAssertEqual(reloaded.screenClientSnapshot().count, 1)
        XCTAssertEqual(reloaded.screenClientSnapshot().first?.name, "iPhone · Safari")
        XCTAssertTrue(reloaded.removeScreenClient(id: "screen-abc12345"))
        XCTAssertTrue(reloaded.screenClientSnapshot().isEmpty)
    }
}
