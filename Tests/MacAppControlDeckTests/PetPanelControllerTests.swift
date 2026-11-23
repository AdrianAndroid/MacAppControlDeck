import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetPanelControllerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var controller: PetPanelController?

    override func setUp() {
        super.setUp()
        suiteName = "pet-panel-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        let settings = PetSettings(defaults: defaults)
        let state = PetStateMachine(settings: settings)
        controller = PetPanelController(settings: settings, state: state)
    }

    override func tearDown() {
        controller?.shutdown()
        controller = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testShowCreatesWindowAtConfiguredSize() {
        guard let controller else { return XCTFail("missing controller") }
        controller.show()
        XCTAssertTrue(controller.isOpen)
        XCTAssertEqual(controller.window.frame.size, PetGeometry.windowSize(for: .medium, bongoCat: true))
    }

    func testResizeKeepsBottomCenterAndUpdatesWindowSize() {
        guard let controller else { return XCTFail("missing controller") }
        controller.show()
        let oldFrame = controller.window.frame
        controller.settings.size = .large
        controller.resize(to: .large, animated: false)
        let newFrame = controller.window.frame
        XCTAssertEqual(newFrame.size, PetGeometry.windowSize(for: .large, bongoCat: true))
        XCTAssertEqual(newFrame.minY, oldFrame.minY, accuracy: 2)
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: oldFrame.midX, y: oldFrame.minY)) }
            ?? NSScreen.main
        if let screen {
            let expectedMidX = min(
                max(oldFrame.midX, screen.visibleFrame.minX + newFrame.width / 2),
                screen.visibleFrame.maxX - newFrame.width / 2
            )
            XCTAssertEqual(newFrame.midX, expectedMidX, accuracy: 1)
        }
    }

    func testClickThroughForcesWindowToIgnoreMouse() {
        guard let controller else { return XCTFail("missing controller") }
        controller.show()
        controller.settings.clickThrough = true
        controller.refresh()
        XCTAssertTrue(controller.window.ignoresMouseEvents)

    }

    func testFullScreenSettingUpdatesCollectionBehavior() {
        guard let controller else { return XCTFail("missing controller") }
        controller.settings.allowFullScreen = true
        controller.refresh()
        XCTAssertTrue(controller.window.collectionBehavior.contains(.fullScreenAuxiliary))
        controller.settings.allowFullScreen = false
        controller.refresh()
        XCTAssertFalse(controller.window.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
