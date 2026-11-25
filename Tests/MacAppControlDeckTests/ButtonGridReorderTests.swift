import XCTest
@testable import MacAppControlDeck

final class ButtonGridReorderTests: XCTestCase {
    private let frames: [String: CGRect] = [
        "a": CGRect(x: 0, y: 0, width: 120, height: 118),
        "b": CGRect(x: 130, y: 0, width: 120, height: 118),
        "c": CGRect(x: 260, y: 0, width: 120, height: 118),
        "d": CGRect(x: 390, y: 0, width: 120, height: 118)
    ]

    func testEmptyOrderReturnsZero() {
        XCTAssertEqual(
            ButtonGridReorder.targetIndex(pointer: CGPoint(x: 20, y: 20), frames: [:], order: []),
            0
        )
    }

    func testDropBeforeFirstCard() {
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 20, y: 59),
            frames: frames,
            order: ["b", "c", "d"]
        )
        XCTAssertEqual(index, 0)
    }

    func testDropBetweenSecondAndThirdCards() {
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 256, y: 59),
            frames: frames,
            order: ["a", "b", "d"]
        )
        XCTAssertEqual(index, 2)
    }

    func testDropBeforeSecondCard() {
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 124, y: 59),
            frames: frames,
            order: ["a", "b", "c", "d"]
        )
        XCTAssertEqual(index, 1)
    }

    func testDropAfterLastCard() {
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 540, y: 59),
            frames: frames,
            order: ["b", "c", "d"]
        )
        XCTAssertEqual(index, 3)
    }

    func testDropInLastRowUsesVisibleFramesNotGroupEnd() {
        let scrolledFrames: [String: CGRect] = [
            "c": CGRect(x: 0, y: 0, width: 120, height: 118),
            "d": CGRect(x: 130, y: 0, width: 120, height: 118),
            "e": CGRect(x: 260, y: 0, width: 120, height: 118),
            "f": CGRect(x: 390, y: 0, width: 120, height: 118)
        ]
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 20, y: -40),
            frames: scrolledFrames,
            order: ["a", "b", "c", "d", "e", "f", "g"]
        )
        // 视口顶部是 c，不是整组第 0 项；不能把拖动误判成回到组首。
        XCTAssertEqual(index, 2)
    }

    func testDropWithMissingFramesIsSafe() {
        let sparse: [String: CGRect] = [
            "b": CGRect(x: 0, y: 0, width: 120, height: 118)
        ]
        let index = ButtonGridReorder.targetIndex(
            pointer: CGPoint(x: 200, y: 59),
            frames: sparse,
            order: ["a", "b", "c"]
        )
        XCTAssertEqual(index, 2)
    }
}
