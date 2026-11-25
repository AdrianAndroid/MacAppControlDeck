import XCTest
@testable import MacAppControlDeck

final class ScreenHTMLTests: XCTestCase {
    func testContentLoadsFromResource() {
        XCTAssertFalse(ScreenHTML.content.isEmpty, "副屏 HTML 资源未加载，页面会白屏")
        XCTAssertTrue(ScreenHTML.content.contains("<!DOCTYPE html>"))
        XCTAssertTrue(ScreenHTML.content.contains("id=\"dial\""))
        XCTAssertTrue(ScreenHTML.content.contains("id=\"petBox\""))
        XCTAssertGreaterThan(ScreenHTML.content.utf8.count, 70_000)
    }

    func testVersionPlaceholderIsReplaced() {
        XCTAssertFalse(ScreenHTML.content.contains("%%SCREEN_VERSION%%"), "版本号占位符未替换")
        XCTAssertFalse(ScreenHTML.content.contains("\\(version)"), "不应残留 Swift 插值文本")
        XCTAssertTrue(ScreenHTML.content.contains(
            "<meta name=\"screen-version\" content=\"\(ScreenHTML.version)\">"
        ))
    }
}
