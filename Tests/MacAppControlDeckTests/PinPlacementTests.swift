import AppKit
import XCTest
@testable import MacShotKit

/// 区域截图点击 pin 后，图片必须落在原框选位置，而不是屏幕中心。
final class PinPlacementTests: XCTestCase {

    private let mainScreen = NSRect(x: 0, y: 0, width: 1920, height: 1080)

    func testCaptureSourcePinsOverOriginalSelection() {
        let selection = NSRect(x: 320, y: 240, width: 480, height: 300)
        let source = PinSource(rect: selection, contentOrigin: nil)

        let frame = PinWindowController.initialFrame(
            imageSize: selection.size,
            source: source,
            placement: .captureLocation,
            screenFrames: [mainScreen],
            preferredVisibleFrame: mainScreen
        )

        XCTAssertEqual(frame.origin.x, selection.minX, accuracy: 0.01)
        XCTAssertEqual(frame.origin.y, selection.minY, accuracy: 0.01)
        XCTAssertEqual(frame.size.width, selection.width, accuracy: 0.01)
        XCTAssertEqual(frame.size.height, selection.height, accuracy: 0.01)
    }

    func testCaptureSourceShrinksLargeImageAroundSelectionCenter() {
        // 大图按 80% 屏幕上限缩放，但仍围绕原框选中心，不跳到屏幕中心。
        let selection = NSRect(x: 700, y: 500, width: 400, height: 300)
        let imageSize = NSSize(width: 2000, height: 1500)
        let source = PinSource(rect: selection, contentOrigin: nil)

        let frame = PinWindowController.initialFrame(
            imageSize: imageSize,
            source: source,
            placement: .captureLocation,
            screenFrames: [mainScreen],
            preferredVisibleFrame: mainScreen
        )

        XCTAssertEqual(frame.midX, selection.midX, accuracy: 0.01)
        // 缩放后 frame 可能被 clamp 进屏幕边界吸收像素取整，允许几pt偏差。
        XCTAssertEqual(frame.midY, selection.midY, accuracy: 3.0)
        XCTAssertLessThanOrEqual(frame.width, mainScreen.width * 0.8 + 0.01)
        XCTAssertLessThanOrEqual(frame.height, mainScreen.height * 0.8 + 0.01)
    }

    func testCrossScreenSelectionKeepsFullSize() {
        let left = NSRect(x: -1000, y: 0, width: 1000, height: 800)
        let right = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let selection = NSRect(x: -200, y: 100, width: 600, height: 400)
        let source = PinSource(rect: selection, contentOrigin: nil)

        let frame = PinWindowController.initialFrame(
            imageSize: selection.size,
            source: source,
            placement: .captureLocation,
            screenFrames: [left, right],
            preferredVisibleFrame: right
        )

        XCTAssertEqual(frame.size.width, selection.width, accuracy: 0.01)
        XCTAssertEqual(frame.size.height, selection.height, accuracy: 0.01)
        XCTAssertEqual(frame.midX, selection.midX, accuracy: 0.01)
    }

    func testNoSourceStillCenters() {
        let frame = PinWindowController.initialFrame(
            imageSize: NSSize(width: 400, height: 300),
            source: nil,
            placement: .screenCenter,
            screenFrames: [mainScreen],
            preferredVisibleFrame: mainScreen
        )

        XCTAssertEqual(frame.midX, mainScreen.midX, accuracy: 0.01)
        XCTAssertEqual(frame.midY, mainScreen.midY, accuracy: 0.01)
    }

    func testMissingSourceScreenFallsBackToCenter() {
        // 来源显示器已拔掉：captureLocationFrame 返回 nil，退回屏幕中心而不是乱落。
        let selection = NSRect(x: 320, y: 240, width: 480, height: 300)
        let source = PinSource(rect: selection, contentOrigin: nil)

        let frame = PinWindowController.initialFrame(
            imageSize: selection.size,
            source: source,
            placement: .captureLocation,
            screenFrames: [],
            preferredVisibleFrame: mainScreen
        )

        XCTAssertEqual(frame.midX, mainScreen.midX, accuracy: 0.01)
        XCTAssertEqual(frame.midY, mainScreen.midY, accuracy: 0.01)
    }

    func testCaptureLocationDoesNotDependOnStoredPlacementPreference() {
        // 即便偏好被写成「居中」，来自区域截图的 pin 仍落在原位。
        let selection = NSRect(x: 150, y: 90, width: 300, height: 200)
        let source = PinSource(rect: selection, contentOrigin: nil)

        UserDefaults.standard.set(PinPlacement.screenCenter.rawValue,
                                  forKey: PinPlacement.userDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: PinPlacement.userDefaultsKey) }

        XCTAssertEqual(PinWindowController.placement(for: source), .captureLocation)

        let frame = PinWindowController.initialFrame(
            imageSize: selection.size,
            source: source,
            placement: PinWindowController.placement(for: source),
            screenFrames: [mainScreen],
            preferredVisibleFrame: mainScreen
        )

        XCTAssertEqual(frame.origin.x, selection.minX, accuracy: 0.01)
        XCTAssertEqual(frame.origin.y, selection.minY, accuracy: 0.01)
    }

    func testNoSourceFollowsStoredPreference() {
        UserDefaults.standard.set(PinPlacement.screenCenter.rawValue,
                                  forKey: PinPlacement.userDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: PinPlacement.userDefaultsKey) }

        XCTAssertEqual(PinWindowController.placement(for: nil), .screenCenter)
    }
}
