import XCTest
@testable import MacAppControlDeck

final class ScreenDisplaySettingsTests: XCTestCase {
    func testDefaultConfigIsValid() {
        let config = ScreenDisplayConfig.default
        XCTAssertEqual(config.size, "m")
        XCTAssertEqual(config.petMode, "fixed")
        XCTAssertEqual(config.petId, "cat")
        XCTAssertEqual(config.petInterval, 60)
        XCTAssertTrue(config.keepAwake)
        XCTAssertEqual(config.petSwitchNonce, 0)
        XCTAssertTrue(config.petVisible)
        XCTAssertTrue(config.petLive)
    }


    func testNormalizedClampsInvalidValues() {
        let config = ScreenDisplayConfig(size: "xl", petMode: "weird", petId: "bird",
                                         petInterval: 7, keepAwake: false, petSwitchNonce: 3)
        let normalized = config.normalized
        XCTAssertEqual(normalized.size, "m")
        XCTAssertEqual(normalized.petMode, "fixed")
        XCTAssertEqual(normalized.petId, "cat")
        XCTAssertEqual(normalized.petInterval, 60)
        XCTAssertFalse(normalized.keepAwake)
        XCTAssertEqual(normalized.petSwitchNonce, 3)
    }

    func testRequestPetSwitchAdvancesFixedPet() {
        let suiteName = "deck-screen-display-test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试 UserDefaults")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        // 通过反射注入测试用 defaults，避免污染真实设置。
        let settings = ScreenDisplaySettings(defaults: defaults)
        settings.petMode = "fixed"
        settings.petId = "cat"
        let nonceBefore = settings.petSwitchNonce

        settings.requestPetSwitch()
        XCTAssertEqual(settings.petId, "dog")
        XCTAssertEqual(settings.petSwitchNonce, nonceBefore + 1)

        settings.requestPetSwitch()
        XCTAssertEqual(settings.petId, "robot")
        settings.requestPetSwitch()
        XCTAssertEqual(settings.petId, "capybara")
        settings.requestPetSwitch()
        XCTAssertEqual(settings.petId, "cat")
    }

    func testRequestPetSwitchKeepsPetIdInRandomMode() {
        let suiteName = "deck-screen-display-random-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试 UserDefaults")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = ScreenDisplaySettings(defaults: defaults)
        settings.petMode = "random"
        settings.petId = "dog"
        let nonceBefore = settings.petSwitchNonce

        settings.requestPetSwitch()
        XCTAssertEqual(settings.petId, "dog")
        XCTAssertEqual(settings.petSwitchNonce, nonceBefore + 1)
    }
}


final class ScreenFrameConfigTests: XCTestCase {
    func testViewportBorderDefaultsToOff() {
        let config = ScreenFrameConfig.default
        XCTAssertTrue(config.enabled)
        XCTAssertFalse(config.viewportBorder)
    }

    func testViewportBorderSurvivesSettingsRoundTrip() {
        let suiteName = "deck-screen-frame-test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试 UserDefaults")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = ScreenAppearanceSettings(defaults: defaults)
        XCTAssertFalse(settings.viewportBorder)
        settings.viewportBorder = true
        XCTAssertTrue(settings.config.viewportBorder)

        let reloaded = ScreenAppearanceSettings(defaults: defaults)
        XCTAssertTrue(reloaded.viewportBorder)
    }

    func testPaddingDefaultsToZero() {
        let config = ScreenFrameConfig.default
        XCTAssertEqual(config.paddingTop, 0)
        XCTAssertEqual(config.paddingRight, 0)
        XCTAssertEqual(config.paddingBottom, 0)
        XCTAssertEqual(config.paddingLeft, 0)
    }

    func testPaddingSurvivesSettingsRoundTrip() {
        let suiteName = "deck-screen-frame-padding-test-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("无法创建测试 UserDefaults")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = ScreenAppearanceSettings(defaults: defaults)
        settings.paddingTop = 8
        settings.paddingRight = 12
        settings.paddingBottom = 16
        settings.paddingLeft = 20
        let config = settings.config
        XCTAssertEqual([config.paddingTop, config.paddingRight, config.paddingBottom, config.paddingLeft],
                       [8, 12, 16, 20])

        let reloaded = ScreenAppearanceSettings(defaults: defaults)
        XCTAssertEqual([reloaded.paddingTop, reloaded.paddingRight, reloaded.paddingBottom, reloaded.paddingLeft],
                       [8, 12, 16, 20])
    }

    func testPaddingIsClamped() {
        let negative = ScreenFrameConfig(enabled: true, strength: 0.16,
                                         paddingTop: -10, paddingRight: 999, paddingBottom: 0, paddingLeft: 30)
        XCTAssertEqual(negative.normalized.paddingTop, 0)
        XCTAssertEqual(negative.normalized.paddingRight, ScreenFrameConfig.paddingRange.upperBound)
        XCTAssertEqual(negative.normalized.paddingLeft, 30)
    }
}
