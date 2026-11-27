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

    func testHeroIconAssetsLoadFromResource() {
        guard let data = ScreenHTML.iconData(named: "clear-day") else {
            return XCTFail("Meteocons 动画图标未打进资源 bundle")
        }
        let svg = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(svg.contains("viewBox=\"0 0 128 128\""))
        XCTAssertTrue(svg.contains("<animate"), "主图标应为 SMIL 动画 SVG")
    }

    func testStaticHeroIconVariantHasNoAnimation() {
        guard let data = ScreenHTML.iconData(named: "static-clear-day") else {
            return XCTFail("Meteocons 静态图标未打进资源 bundle")
        }
        let svg = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(svg.contains("viewBox=\"0 0 128 128\""))
        XCTAssertFalse(svg.contains("<animate"), "静态版本不应包含 SMIL 动画")
    }

    func testHeroIconAssetNamesAreValidated() {
        XCTAssertNil(ScreenHTML.iconData(named: "../index"))
        XCTAssertNil(ScreenHTML.iconData(named: "Clear-Day"))
        XCTAssertNil(ScreenHTML.iconData(named: "not-a-real-icon"))
    }

    func testHotColdAndDustCodesUseAnimatedAssets() {
        XCTAssertTrue(ScreenHTML.content.contains("'900': 'sun-hot'"))
        XCTAssertTrue(ScreenHTML.content.contains("'901': 'thermometer-mercury-cold'"))
        XCTAssertTrue(ScreenHTML.content.contains("'503': 'dust'"))
        XCTAssertTrue(ScreenHTML.content.contains("n >= 500 && n < 600"), "未知天气族应尽量兜底")
        XCTAssertNotNil(ScreenHTML.iconData(named: "thermometer-mercury-cold"))
        XCTAssertNotNil(ScreenHTML.iconData(named: "sun-hot"))
        XCTAssertNotNil(ScreenHTML.iconData(named: "dust"))
    }

    func testScreenReportsPresenceForDevicesPage() {
        XCTAssertTrue(ScreenHTML.content.contains("/api/screen/presence"))
        XCTAssertTrue(ScreenHTML.content.contains("SCREEN_CLIENT_KEY"))
    }

    func testPanelSupportsQRCodeAutoPairing() {
        XCTAssertTrue(PanelHTML.content.contains("autoCode"))
        XCTAssertTrue(PanelHTML.content.contains("pair"))
        XCTAssertTrue(PanelHTML.content.contains("history.replaceState"))
    }

    func testPageUsesAssetLoaderAndKeepsStaticSmallIcons() {
        XCTAssertTrue(ScreenHTML.content.contains("/screen/icons/"))
        XCTAssertTrue(ScreenHTML.content.contains("WX_HERO_ASSETS"))
        XCTAssertFalse(ScreenHTML.content.contains("wxa-"), "自写动画样式应已移除")
    }
}
