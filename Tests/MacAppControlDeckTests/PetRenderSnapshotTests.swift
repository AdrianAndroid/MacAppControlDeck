import AppKit
import SwiftUI
import XCTest
@testable import MacAppControlDeck

@MainActor
final class PetRenderSnapshotTests: XCTestCase {

    func testReferenceMotionPosesRender() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pet-motion-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let skin = PetSkinCatalog.all.first { $0.id == "midnight-black" } ?? PetSkinCatalog.defaultSkin
        let typingKeys = [PetKeyPress(code: 12, label: "Q", zone: .left, depth: 1),
                          PetKeyPress(code: 0, label: "A", zone: .left, depth: 1),
                          PetKeyPress(code: 49, label: "space", zone: .center, depth: 1)]
        let keycaps = [
            PetKeycap(id: 1, label: "Q", slot: 0, progress: 0.2, isModifier: false),
            PetKeycap(id: 2, label: "A", slot: 1, progress: 0.4, isModifier: false),
            PetKeycap(id: 3, label: "⌘", slot: 2, progress: 0.6, isModifier: true),
            PetKeycap(id: 4, label: "S", slot: 3, progress: 0.3, isModifier: false)
        ]
        let snapshots: [(String, PetSnapshot)] = [
            ("typing", PetSnapshot(
                pawLeft: 1, pawRight: 1,
                leftPawPoint: PetPoint(30, 342), rightPawPoint: PetPoint(110, 330),
                squint: 0.35, eyeX: -0.35, eyeY: 0.5, headYaw: 3,
                bodyBounce: 0.03, bodyLean: -2.5,
                pressedKeys: typingKeys, keycaps: keycaps
            )),
            ("mouse", PetSnapshot(
                pawLeft: 0.4,
                leftPawPoint: PetPoint(22, 340), rightPawPoint: PetPoint(176, 326),
                eyeX: -0.8, eyeY: 0.2, headYaw: -6,
                bodyLean: -4, mouseShift: PetPoint(-2, 1)
            )),
            ("sleep", PetSnapshot(blink: 1, tailWag: 0.1, sleeping: 1))
        ]
        for (name, snapshot) in snapshots {
            let view = PetVectorArt(
                skin: skin,
                theme: skin.defaultKeyboardTheme,
                detail: .standard,
                snapshot: snapshot
            )
            .frame(width: PetGeometry.visualSize(for: .medium).width,
                   height: PetGeometry.visualSize(for: .medium).height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                XCTFail("motion pose \(name) render failed")
                continue
            }
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        }
        print("PET_MOTION_DIR=\(directory.path)")
    }


    func testPetSettingsViewRenders() throws {
        let view = PetSettingsView()
            .frame(width: 600, height: 760)
            .background(Color(nsColor: .windowBackgroundColor))
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: 600, height: 760)
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return XCTFail("settings bitmap failed")
        }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            return XCTFail("settings png failed")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pet-settings-v2.png")
        try png.write(to: url)
        print("PET_SETTINGS=\(url.path)")
    }

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
