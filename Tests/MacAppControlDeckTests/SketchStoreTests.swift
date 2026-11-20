import AppKit
import XCTest
@testable import MacAppControlDeck

@MainActor
final class SketchStoreTests: XCTestCase {
    private var directory: URL!
    private var previousDirectory: String!

    override func setUpWithError() throws {
        previousDirectory = SketchSettings.shared.saveDirectoryPath
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deck-sketch-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        SketchSettings.shared.saveDirectoryPath = directory.path
    }

    override func tearDownWithError() throws {
        SketchSettings.shared.saveDirectoryPath = previousDirectory
        try? FileManager.default.removeItem(at: directory)
    }

    private func makePNG() throws -> Data {
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 24, height: 24).fill()
        NSColor.black.setStroke()
        NSBezierPath(rect: NSRect(x: 4, y: 4, width: 16, height: 16)).stroke()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw SketchError.invalidImage
        }
        return png
    }

    func testSaveWritesPNGAndExcalidrawSource() throws {
        let scene = #"{"type":"excalidraw","version":2,"elements":[{"id":"a"}]}"#
        let result = try SketchStore.shared.save(sceneJSON: scene, pngData: try makePNG())

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.pngURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.sourceURL.path))
        XCTAssertEqual(try String(contentsOf: result.sourceURL, encoding: .utf8), scene)
        XCTAssertEqual(result.pngURL.deletingPathExtension().lastPathComponent,
                       result.sourceURL.deletingPathExtension().lastPathComponent)
        XCTAssertTrue(result.pngURL.lastPathComponent.hasPrefix("UI-Sketch-"))
        XCTAssertGreaterThan(try Data(contentsOf: result.pngURL).count, 0)
    }

    func testConsecutiveSavesNeverOverwrite() throws {
        let scene = #"{"type":"excalidraw","version":2,"elements":[{"id":"b"}]}"#
        let first = try SketchStore.shared.save(sceneJSON: scene, pngData: try makePNG())
        let second = try SketchStore.shared.save(sceneJSON: scene, pngData: try makePNG())

        XCTAssertNotEqual(first.pngURL, second.pngURL)
        XCTAssertNotEqual(first.sourceURL, second.sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.pngURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.pngURL.path))
    }

    func testEmptySceneIsRejected() throws {
        XCTAssertThrowsError(try SketchStore.shared.save(sceneJSON: "", pngData: try makePNG())) { error in
            XCTAssertEqual((error as? SketchError), .emptyBoard)
        }
    }

    func testInvalidPNGIsRejected() throws {
        XCTAssertThrowsError(try SketchStore.shared.save(sceneJSON: "{}", pngData: Data("not a png".utf8))) { error in
            XCTAssertEqual((error as? SketchError), .invalidImage)
        }
    }
}
