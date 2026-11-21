import AppKit
import SwiftUI
import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetRenderSnapshotTests: XCTestCase {
    func testEverySkinAndSizeRendersWithoutCrash() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pet-renders-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for skin in PetSkinCatalog.all {
            for size in PetSize.allCases {
                let view = PetVectorArt(
                    skin: skin,
                    theme: skin.defaultKeyboardTheme,
                    detail: size.detail,
                    snapshot: PetSnapshot(blink: 0.2, bodyBounce: 0.01, tailWag: 0.4, earTwitch: 0.1)
                )
                .frame(
                    width: PetGeometry.visualSize(for: size).width,
                    height: PetGeometry.visualSize(for: size).height
                )
                let renderer = ImageRenderer(content: view)
                renderer.scale = 2
                let image = renderer.nsImage
                XCTAssertNotNil(image, "\(skin.id) \(size.rawValue) should render")
                guard let tiff = image?.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:]) else {
                    XCTFail("PNG encode failed for \(skin.id) \(size.rawValue)")
                    continue
                }
                let url = directory.appendingPathComponent("\(skin.id)-\(size.rawValue).png")
                try png.write(to: url)
                XCTAssertGreaterThan(bitmap.pixelsWide, 0)
                XCTAssertGreaterThan(bitmap.pixelsHigh, 0)
            }
        }
        print("PET_RENDER_DIR=\(directory.path)")
    }
}
