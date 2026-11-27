import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class CaptureStatusBarEntryTests: XCTestCase {
    func testMetadata() {
        let entry = CaptureStatusBarEntry(capture: {})
        XCTAssertEqual(entry.id, "capture.region")
        XCTAssertEqual(entry.moduleID, CaptureModule.id)
        XCTAssertEqual(entry.groupID, CaptureModule.id)
        XCTAssertEqual(entry.order, 4)
        XCTAssertTrue(entry.defaultVisible)
        XCTAssertEqual(entry.title, "区域截图")
    }

    func testMakeViewIsCompactStatusIcon() {
        let entry = CaptureStatusBarEntry(capture: {})
        let view = entry.makeView()
        XCTAssertEqual(view.frame.size, NSSize(width: 22, height: 22))
        XCTAssertEqual(view.subviews.count, 1)
        XCTAssertEqual(view.toolTip, "区域截图")
    }
}
