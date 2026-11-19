import AppKit
import SwiftUI
import XCTest
@testable import MacAppControlDeck

final class ModuleRegistryTests: XCTestCase {
    private final class FakeModule: FeatureModule {
        let id: String
        let title = "测试模块"
        let summary = "仅用于测试"
        let systemImage = "square"
        let defaultEnabled: Bool
        var startCount = 0
        var stopCount = 0

        init(id: String, defaultEnabled: Bool) {
            self.id = id
            self.defaultEnabled = defaultEnabled
        }

        func start() { startCount += 1 }
        func stop() { stopCount += 1 }
        func menuItems() -> [NSMenuItem] {
            [NSMenuItem(title: id, action: nil, keyEquivalent: "")]
        }
        func settingsView() -> AnyView { AnyView(EmptyView()) }
    }

    func testDefaultEnabledStartsModuleAndExposesMenu() {
        let id = "test.module.\(UUID().uuidString)"
        let module = FakeModule(id: id, defaultEnabled: true)
        let registry = ModuleRegistry()

        registry.register(module)

        XCTAssertTrue(registry.isEnabled(id))
        XCTAssertEqual(module.startCount, 1)
        XCTAssertEqual(registry.menuItems().count, 1)
        UserDefaults.standard.removeObject(forKey: "module.enabled.\(id)")
    }

    func testDisableStopsModuleAndHidesMenuWithoutAffectingOthers() {
        let firstID = "test.module.\(UUID().uuidString)"
        let secondID = "test.module.\(UUID().uuidString)"
        let first = FakeModule(id: firstID, defaultEnabled: true)
        let second = FakeModule(id: secondID, defaultEnabled: true)
        let registry = ModuleRegistry()
        registry.register(first)
        registry.register(second)

        registry.setEnabled(firstID, false)

        XCTAssertFalse(registry.isEnabled(firstID))
        XCTAssertEqual(first.stopCount, 1)
        XCTAssertTrue(registry.isEnabled(secondID))
        XCTAssertEqual(second.startCount, 1)
        XCTAssertEqual(registry.menuItems().count, 1)

        registry.setEnabled(firstID, true)
        XCTAssertEqual(first.startCount, 2)
        XCTAssertEqual(registry.menuItems().count, 2)

        UserDefaults.standard.removeObject(forKey: "module.enabled.\(firstID)")
        UserDefaults.standard.removeObject(forKey: "module.enabled.\(secondID)")
    }
}
