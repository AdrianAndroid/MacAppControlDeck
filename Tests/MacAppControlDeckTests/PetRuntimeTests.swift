import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetRuntimeTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var runtime: PetRuntime?

    override func setUp() {
        super.setUp()
        suiteName = "pet-runtime-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        runtime = PetRuntime(settings: PetSettings(defaults: defaults))
    }

    override func tearDown() {
        runtime?.shutdown()
        runtime = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testStartShowHideAndShutdown() {
        guard let runtime else { return XCTFail("missing runtime") }
        runtime.start()
        runtime.show()
        XCTAssertTrue(runtime.isOpen)
        XCTAssertTrue(runtime.settings.visible)

        runtime.hide()
        XCTAssertFalse(runtime.isOpen)
        XCTAssertFalse(runtime.settings.visible)

        runtime.shutdown()
        XCTAssertFalse(runtime.isOpen)
        XCTAssertFalse(runtime.settings.visible)
    }

    func testSetSizeUpdatesWindowAndSettings() {
        guard let runtime else { return XCTFail("missing runtime") }
        runtime.start()
        runtime.show()
        XCTAssertEqual(runtime.settings.size, .medium)
        runtime.setSize(.large)
        XCTAssertEqual(runtime.settings.size, .large)
        XCTAssertEqual(runtime.isOpen, true)
    }
}
