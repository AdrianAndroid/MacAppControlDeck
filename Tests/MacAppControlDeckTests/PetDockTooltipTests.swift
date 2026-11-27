import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetDockTooltipTests: XCTestCase {
    private let visible = NSRect(x: 0, y: 0, width: 1200, height: 900)

    func testSitsAboveDockAndCentersOnTile() {
        let dock = NSRect(x: 200, y: 100, width: 300, height: 52)
        let frame = PetDockTooltip.frame(anchorX: 150,
                                         dockFrame: dock,
                                         size: NSSize(width: 60, height: 19),
                                         visibleFrame: visible)
        XCTAssertEqual(frame.minX, 320)
        XCTAssertEqual(frame.minY, 158)
        XCTAssertEqual(frame.size, NSSize(width: 60, height: 19))
    }

    func testFlipsBelowWhenNoRoomAbove() {
        let dock = NSRect(x: 200, y: 850, width: 300, height: 52)
        let frame = PetDockTooltip.frame(anchorX: 150,
                                         dockFrame: dock,
                                         size: NSSize(width: 60, height: 19),
                                         visibleFrame: visible)
        XCTAssertEqual(frame.minY, 825)
    }

    func testClampsHorizontallyToVisibleFrame() {
        let dock = NSRect(x: 0, y: 100, width: 300, height: 52)
        let left = PetDockTooltip.frame(anchorX: 5,
                                        dockFrame: dock,
                                        size: NSSize(width: 200, height: 19),
                                        visibleFrame: visible)
        XCTAssertEqual(left.minX, 6)

        let edgeDock = NSRect(x: 1150, y: 100, width: 300, height: 52)
        let right = PetDockTooltip.frame(anchorX: 150,
                                         dockFrame: edgeDock,
                                         size: NSSize(width: 200, height: 19),
                                         visibleFrame: visible)
        XCTAssertEqual(right.maxX, visible.maxX - 6)
    }

    func testSizeCapsLongNames() {
        let size = PetDockTooltip.size(for: String(repeating: "很长的应用名称", count: 12))
        XCTAssertEqual(size.width, 280)
        XCTAssertLessThanOrEqual(size.height, 24)
    }
}
