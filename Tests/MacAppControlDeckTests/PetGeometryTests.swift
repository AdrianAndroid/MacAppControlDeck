import XCTest
@testable import MacAppControlDeck

final class PetGeometryTests: XCTestCase {
    func testWindowSizesKeepSameVisualRatio() {
        XCTAssertEqual(PetGeometry.visualSize(for: .small), CGSize(width: 180, height: 105))
        XCTAssertEqual(PetGeometry.visualSize(for: .medium), CGSize(width: 240, height: 140))
        XCTAssertEqual(PetGeometry.visualSize(for: .large), CGSize(width: 324, height: 189))
        XCTAssertEqual(
            PetGeometry.windowSize(for: .medium),
            CGSize(width: 248, height: 148)
        )
    }

    func testResizeKeepsBottomCenterAnchor() {
        let anchor = CGPoint(x: 500, y: 100)
        let small = PetGeometry.frame(anchor: anchor, size: .small)
        let large = PetGeometry.frame(anchor: anchor, size: .large)
        XCTAssertEqual(small.midX, large.midX, accuracy: 0.5)
        XCTAssertEqual(small.minY, large.minY, accuracy: 0.5)
    }

    func testClampKeepsWholeWindowInsideVisibleFrame() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = CGRect(x: 1400, y: -20, width: 220, height: 150)
        let clamped = PetGeometry.clamp(frame, to: visible)
        XCTAssertEqual(clamped.maxX, visible.maxX)
        XCTAssertEqual(clamped.minY, visible.minY)
    }

    func testNormalizedPositionRoundTrip() {
        let visible = CGRect(x: 100, y: 50, width: 1200, height: 800)
        let frame = CGRect(x: 900, y: 120, width: 248, height: 148)
        let point = PetGeometry.normalizedPosition(of: frame, in: visible)
        let restored = PetGeometry.frame(normalizedPosition: point, in: visible, size: .medium)
        XCTAssertEqual(restored.origin.x, frame.origin.x, accuracy: 1)
        XCTAssertEqual(restored.origin.y, frame.origin.y, accuracy: 1)
    }

    func testHitPathFollowsBodyAndKeyboardNotWindowCorners() {
        let bounds = CGRect(x: 0, y: 0, width: 240, height: 140)
        let skin = PetSkinCatalog.defaultSkin
        XCTAssertFalse(PetGeometry.contains(CGPoint(x: 3, y: 3), skin: skin, in: bounds))
        XCTAssertTrue(PetGeometry.contains(CGPoint(x: 110, y: 60), skin: skin, in: bounds))
        XCTAssertTrue(PetGeometry.contains(CGPoint(x: 145, y: 118), skin: skin, in: bounds))
    }

    func testPartHitTesting() {
        let bounds = CGRect(x: 0, y: 0, width: 240, height: 140)
        let skin = PetSkinCatalog.defaultSkin
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 120, y: 50), skin: skin, in: bounds), .head)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 48, y: 109), skin: skin, in: bounds), .leftPaw)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 197, y: 112), skin: skin, in: bounds), .rightPaw)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 120, y: 118), skin: skin, in: bounds), .keyboard)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 2, y: 2), skin: skin, in: bounds), .transparent)
    }
}
