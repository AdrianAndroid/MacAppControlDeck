import XCTest
import Carbon.HIToolbox
@testable import MacAppControlDeck

final class GlobalHotKeyTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-hotkey-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCatalogDefaults() {
        let definitions = GlobalHotKeys.makeDefinitions()
        XCTAssertEqual(definitions.count, 10)
        XCTAssertEqual(Set(definitions.map(\.id)).count, definitions.count, "入口 id 必须唯一")
        XCTAssertEqual(Set(definitions.map(\.hotKeyID)).count, definitions.count, "Carbon 热键 id 必须唯一")

        let f1 = definitions.first { $0.id == "capture.area.f1" }
        XCTAssertEqual(f1?.defaultCombo.keyCode, 122)
        XCTAssertEqual(f1?.defaultCombo.modifiers, [])
        XCTAssertEqual(f1?.hotKeyID, GlobalHotKeys.captureAreaF1.id)

        let area = definitions.first { $0.id == "capture.area" }
        XCTAssertEqual(area?.defaultCombo.keyCode, 7)
        XCTAssertEqual(area?.defaultCombo.modifiers, [.command, .shift])
    }

    func testCarbonAndAppKitModifierMapping() {
        XCTAssertEqual(GlobalHotKeyRules.carbonModifiers([.command, .shift]),
                       UInt32(cmdKey | shiftKey))
        XCTAssertEqual(GlobalHotKeyRules.carbonModifiers([.control, .option]),
                       UInt32(controlKey | optionKey))
        XCTAssertEqual(GlobalHotKeyRules.carbonModifiers([]), 0)

        let flags = GlobalHotKeyRules.appKitModifiers([.control, .option])
        XCTAssertTrue(flags.contains(.control))
        XCTAssertTrue(flags.contains(.option))
        XCTAssertFalse(flags.contains(.command))
    }

    func testValidationRules() {
        let definitions = GlobalHotKeys.makeDefinitions()
        var settings = GlobalHotKeys.merged(nil, definitions: definitions)
        var area = settings["capture.area"]!
        area.enabled = true
        settings["capture.area"] = area
        let titles = Dictionary(uniqueKeysWithValues: definitions.map { ($0.id, $0.title) })

        let plainLetter = ShortcutCombo(modifiers: [], keyCode: 7, keyLabel: "X")
        XCTAssertEqual(GlobalHotKeyRules.validate(plainLetter, excluding: "capture.area",
                                                 settings: settings, titles: titles),
                       .needsModifier)

        let f1 = ShortcutCombo(modifiers: [], keyCode: 122, keyLabel: "F1")
        XCTAssertEqual(GlobalHotKeyRules.validate(f1, excluding: "capture.area.f1",
                                                 settings: settings, titles: titles),
                       .ok)

        let duplicate = ShortcutCombo(modifiers: [.shift, .command], keyCode: 7, keyLabel: "X")
        XCTAssertEqual(GlobalHotKeyRules.validate(duplicate, excluding: "capture.area.f1",
                                                 settings: settings, titles: titles),
                       .duplicate("区域截图"))

        let unique = ShortcutCombo(modifiers: [.option, .command], keyCode: 99, keyLabel: "F3")
        XCTAssertEqual(GlobalHotKeyRules.validate(unique, excluding: "capture.area.f1",
                                                 settings: settings, titles: titles),
                       .ok)
    }

    func testMergedPreferencesFillDefaults() {
        let definitions = GlobalHotKeys.makeDefinitions()
        let custom = ShortcutCombo(modifiers: [.control, .shift], keyCode: 1, keyLabel: "S")
        let preferences = GlobalHotKeyPreferences(
            masterEnabled: false,
            entries: [
                "capture.area.f1": GlobalHotKeySetting(combo: custom, enabled: false),
                "unknown.entry": GlobalHotKeySetting(combo: custom, enabled: true)
            ])

        let merged = GlobalHotKeys.merged(preferences, definitions: definitions)
        XCTAssertEqual(merged.count, definitions.count)
        XCTAssertNil(merged["unknown.entry"])
        XCTAssertEqual(merged["capture.area.f1"]?.combo.symbol, "⌃⇧S")
        XCTAssertEqual(merged["capture.area.f1"]?.enabled, false)
        XCTAssertEqual(merged["capture.area"]?.combo.keyCode, 7, "缺失入口应回落到默认组合")
        XCTAssertEqual(merged["capture.area"]?.enabled, false, "新增/缺失入口默认关闭")
    }

    func testStoreRoundTrip() {
        let store = GlobalHotKeyStore(directory: directory)
        let combo = ShortcutCombo(modifiers: [.option, .command], keyCode: 99, keyLabel: "F3")
        let preferences = GlobalHotKeyPreferences(
            masterEnabled: false,
            entries: ["capture.area.f1": GlobalHotKeySetting(combo: combo, enabled: false)])
        store.save(preferences)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.load(), preferences)
    }

    func testStoreRejectsBrokenFile() throws {
        let store = GlobalHotKeyStore(directory: directory)
        try Data("not json".utf8).write(to: store.fileURL)
        XCTAssertNil(store.load())
    }

    func testInstanceTogglesComboAndPersists() {
        let store = GlobalHotKeyStore(directory: directory)
        let hotKeys = GlobalHotKeys(store: store)
        XCTAssertTrue(hotKeys.masterEnabled)
        XCTAssertFalse(hotKeys.isEnabled("capture.area.f1"), "默认关闭")

        let plainLetter = ShortcutCombo(modifiers: [], keyCode: 0, keyLabel: "A")
        XCTAssertEqual(hotKeys.setCombo("capture.area.f1", plainLetter), .needsModifier)

        XCTAssertEqual(hotKeys.setEnabled("capture.area", true), .ok)
        let duplicate = ShortcutCombo(modifiers: [.command, .shift], keyCode: 7, keyLabel: "X")
        XCTAssertEqual(hotKeys.setCombo("capture.area.f1", duplicate), .duplicate("区域截图"))

        let unique = ShortcutCombo(modifiers: [.option, .command], keyCode: 99, keyLabel: "F3")
        XCTAssertEqual(hotKeys.setCombo("capture.area.f1", unique), .ok)
        XCTAssertEqual(hotKeys.combo(for: "capture.area.f1").symbol, "⌥⌘F3")

        XCTAssertEqual(hotKeys.setEnabled("capture.area.f1", true), .ok)
        XCTAssertTrue(hotKeys.isEnabled("capture.area.f1"))
        XCTAssertEqual(hotKeys.setEnabled("capture.area.f1", false), .ok)
        XCTAssertFalse(hotKeys.isEnabled("capture.area.f1"))

        hotKeys.setMasterEnabled(false)
        hotKeys.resetAll()
        XCTAssertFalse(hotKeys.masterEnabled, "全部重置只恢复快捷键，不强行打开总开关")
        XCTAssertEqual(hotKeys.combo(for: "capture.area.f1").symbol, "F1")
        XCTAssertFalse(hotKeys.isEnabled("capture.area.f1"), "全部重置后仍是关闭")

        let saved = store.load()
        XCTAssertEqual(saved?.masterEnabled, false)
        XCTAssertEqual(saved?.shortcutsOffByDefault, true)
        XCTAssertEqual(saved?.entries["capture.area.f1"]?.combo.symbol, "F1")
        XCTAssertEqual(saved?.entries["capture.area.f1"]?.enabled, false)
    }


    func testFreshInstallDefaultsToAllOff() {
        let hotKeys = GlobalHotKeys(store: GlobalHotKeyStore(directory: directory))
        XCTAssertTrue(hotKeys.masterEnabled)
        XCTAssertTrue(hotKeys.definitions.allSatisfy { !hotKeys.isEnabled($0.id) },
                      "首次安装不占用任何系统级快捷键")
        XCTAssertEqual(hotKeys.combo(for: "capture.area.f1").symbol, "F1", "组合仍保留默认值")
    }

    func testLegacyPreferencesMigrateToOff() {
        let store = GlobalHotKeyStore(directory: directory)
        let legacy = GlobalHotKeyPreferences(
            masterEnabled: true,
            entries: ["capture.area.f1": GlobalHotKeySetting(
                combo: ShortcutCombo(modifiers: [], keyCode: 122, keyLabel: "F1"),
                enabled: true)])
        store.save(legacy)

        let hotKeys = GlobalHotKeys(store: store)
        XCTAssertFalse(hotKeys.isEnabled("capture.area.f1"))
        XCTAssertFalse(hotKeys.isEnabled("capture.area"))

        let saved = store.load()
        XCTAssertEqual(saved?.shortcutsOffByDefault, true)
        XCTAssertEqual(saved?.entries["capture.area.f1"]?.enabled, false)
    }

    func testSingleResetRestoresDefaultComboAndDisables() {
        let hotKeys = GlobalHotKeys(store: GlobalHotKeyStore(directory: directory))
        XCTAssertEqual(hotKeys.setEnabled("capture.area.f1", true), .ok)
        XCTAssertEqual(hotKeys.setCombo("capture.area.f1",
                                        ShortcutCombo(modifiers: [.option], keyCode: 99, keyLabel: "F3")),
                       .ok)
        XCTAssertEqual(hotKeys.combo(for: "capture.area.f1").symbol, "⌥F3")

        XCTAssertEqual(hotKeys.reset("capture.area.f1"), .ok)
        XCTAssertEqual(hotKeys.combo(for: "capture.area.f1").symbol, "F1")
        XCTAssertFalse(hotKeys.isEnabled("capture.area.f1"))
    }

    func testMenuShortcutFollowsSettings() {
        let hotKeys = GlobalHotKeys(store: GlobalHotKeyStore(directory: directory))
        XCTAssertNil(hotKeys.menuShortcut(for: "sketch.open"), "默认关闭时菜单不显示快捷键")
        XCTAssertEqual(hotKeys.setEnabled("sketch.open", true), .ok)
        XCTAssertEqual(hotKeys.menuShortcut(for: "sketch.open")?.keyEquivalent, "d")
        XCTAssertEqual(hotKeys.menuShortcut(for: "sketch.open")?.modifiers, [.control, .option])

        hotKeys.setEnabled("sketch.open", false)
        XCTAssertNil(hotKeys.menuShortcut(for: "sketch.open"), "单项关闭后菜单不再显示快捷键")

        hotKeys.setMasterEnabled(false)
        XCTAssertNil(hotKeys.menuShortcut(for: "pet.toggle"), "总开关关闭后菜单不再显示快捷键")
    }
}
