import XCTest
@testable import MacAppControlDeck

final class PetGeometryTests: XCTestCase {
    func testWindowSizesKeepSameVisualRatio() {
        XCTAssertEqual(PetGeometry.visualSize(for: .small), CGSize(width: 195, height: 270))
        XCTAssertEqual(PetGeometry.visualSize(for: .medium), CGSize(width: 260, height: 360))
        XCTAssertEqual(PetGeometry.visualSize(for: .large), CGSize(width: 351, height: 486))
        XCTAssertEqual(
            PetGeometry.windowSize(for: .medium),
            CGSize(width: 268, height: 368)
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
        let frame = CGRect(x: 900, y: 120, width: 268, height: 368)
        let point = PetGeometry.normalizedPosition(of: frame, in: visible)
        let restored = PetGeometry.frame(normalizedPosition: point, in: visible, size: .medium)
        XCTAssertEqual(restored.origin.x, frame.origin.x, accuracy: 1)
        XCTAssertEqual(restored.origin.y, frame.origin.y, accuracy: 1)
    }

    func testHitPathFollowsBodyAndKeyboardNotWindowCorners() {
        let bounds = CGRect(x: 0, y: 0, width: 260, height: 360)
        let skin = PetSkinCatalog.defaultSkin
        XCTAssertFalse(PetGeometry.contains(CGPoint(x: 3, y: 3), skin: skin, in: bounds))
        XCTAssertFalse(PetGeometry.contains(CGPoint(x: 258, y: 30), skin: skin, in: bounds))
        XCTAssertTrue(PetGeometry.contains(CGPoint(x: 130, y: 190), skin: skin, in: bounds))
        XCTAssertTrue(PetGeometry.contains(CGPoint(x: 130, y: 330), skin: skin, in: bounds))
    }

    func testPartHitTesting() {
        let bounds = CGRect(x: 0, y: 0, width: 260, height: 360)
        let skin = PetSkinCatalog.defaultSkin
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 130, y: 88), skin: skin, in: bounds), .head)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 34, y: 324), skin: skin, in: bounds), .leftPaw)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 177, y: 324), skin: skin, in: bounds), .rightPaw)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 140, y: 330), skin: skin, in: bounds), .keyboard)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 130, y: 205), skin: skin, in: bounds), .body)
        XCTAssertEqual(PetGeometry.part(at: CGPoint(x: 2, y: 2), skin: skin, in: bounds), .transparent)
    }
}
