import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "pet-settings-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsAreConservative() {
        let settings = PetSettings(defaults: defaults)
        XCTAssertFalse(settings.visible)
        XCTAssertFalse(settings.paused)
        XCTAssertFalse(settings.clickThrough)
        XCTAssertFalse(settings.locked)
        XCTAssertEqual(settings.size, .medium)
        XCTAssertEqual(settings.skinID, PetSkinCatalog.defaultID)
        XCTAssertEqual(settings.keyboardTheme, .cream)
        XCTAssertEqual(settings.sleepMinutes, 5)
        XCTAssertFalse(settings.allowFullScreen)
        XCTAssertTrue(settings.hideDuringCapture)
    }

    func testPetKindPersistsAndOldSettingsDefaultToBongo() {
        defaults.set(false, forKey: "pet.live2d")
        let settings = PetSettings(defaults: defaults)
        XCTAssertEqual(settings.kind, .bongoCat)
        XCTAssertTrue(settings.live2DMode)
        settings.kind = .keyCat
        XCTAssertEqual(PetSettings(defaults: defaults).kind, .keyCat)
    }

    func testUnknownSkinFallsBackToDefault() {
        defaults.set("missing-skin", forKey: "pet.skin")
        let settings = PetSettings(defaults: defaults)
        XCTAssertEqual(settings.skinID, PetSkinCatalog.defaultID)
    }

    func testChooseSkinSwitchesKeyboardTheme() {
        let settings = PetSettings(defaults: defaults)
        settings.chooseSkin("cream-dog")
        XCTAssertEqual(settings.skinID, "cream-dog")
        XCTAssertEqual(settings.keyboardTheme, PetSkinCatalog.creamDog.defaultKeyboardTheme)
    }

    func testPositionPersistsPerScreenAndResetClears() {
        let settings = PetSettings(defaults: defaults)
        settings.savePosition(CGPoint(x: 0.42, y: 0.13), for: "screen-a")
        XCTAssertEqual(settings.savedPosition(for: "screen-a")?.x, 0.42)
        XCTAssertEqual(settings.savedPosition(for: "screen-a")?.y, 0.13)

        let reloaded = PetSettings(defaults: defaults)
        XCTAssertEqual(reloaded.savedPosition(for: "screen-a")?.x, 0.42)

        reloaded.resetPosition()
        XCTAssertNil(reloaded.savedPosition(for: "screen-a"))
    }

    func testSizeAndVisibilityPersist() {
        let settings = PetSettings(defaults: defaults)
        settings.size = .large
        settings.visible = true
        settings.clickThrough = true

        let reloaded = PetSettings(defaults: defaults)
        XCTAssertEqual(reloaded.size, .large)
        XCTAssertTrue(reloaded.visible)
        XCTAssertTrue(reloaded.clickThrough)
    }
}
