import XCTest
@testable import MacAppControlDeck

final class PetSkinCatalogTests: XCTestCase {
    func testFiveStableSkinsAndDefault() {
        XCTAssertEqual(PetSkinCatalog.all.count, 5)
        XCTAssertEqual(Set(PetSkinCatalog.all.map(\.id)).count, 5)
        XCTAssertEqual(PetSkinCatalog.defaultSkin.id, PetSkinCatalog.defaultID)
        XCTAssertEqual(PetSkinCatalog.skin(id: "classic-white")?.name, "经典白猫")
        XCTAssertNotNil(PetSkinCatalog.skin(id: "midnight-black"))
        XCTAssertNotNil(PetSkinCatalog.skin(id: "orange-tabby"))
        XCTAssertNotNil(PetSkinCatalog.skin(id: "calico"))
        XCTAssertNotNil(PetSkinCatalog.skin(id: "cream-dog"))
    }

    func testEverySkinHasHitRegionsAndAnchorsInsideVisualSlot() {
        for skin in PetSkinCatalog.all {
            XCTAssertFalse(skin.hitRegions.isEmpty)
            let points = [skin.anchors.head, skin.anchors.body, skin.anchors.leftPaw,
                          skin.anchors.rightPaw, skin.anchors.keyboard]
            for point in points {
                XCTAssertTrue((0...1).contains(point.x))
                XCTAssertTrue((0...1).contains(point.y))
            }
        }
    }

    func testBlackCatUsesLightOutlineForDarkWallpapers() {
        let skin = PetSkinCatalog.midnightBlack
        let outline = skin.palette.outline
        let body = skin.palette.body
        XCTAssertGreaterThan(outline.red + outline.green + outline.blue,
                             body.red + body.green + body.blue)
    }
}
