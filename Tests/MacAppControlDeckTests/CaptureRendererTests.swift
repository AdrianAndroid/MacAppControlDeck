import AppKit
import CoreGraphics
import CoreMedia
import ImageIO
import XCTest
@testable import MacShotKit

final class CaptureRendererTests: XCTestCase {
    func testRenderCropsToRequestedPixelSize() throws {
        let source = makeImage(width: 120, height: 80, color: .systemRed)
        let rendered = AnnotationRenderer.render(
            image: source,
            annotations: [],
            cropRect: CGRect(x: 10, y: 10, width: 60, height: 40))

        XCTAssertNotNil(rendered)
        XCTAssertEqual(rendered?.width, 60)
        XCTAssertEqual(rendered?.height, 40)
    }

    func testRenderDrawsAnnotationsAndKeepsSize() throws {
        let source = makeImage(width: 100, height: 100, color: .white)
        let annotation = CaptureAnnotation(tool: .rectangle,
                                            start: CGPoint(x: 10, y: 10),
                                            end: CGPoint(x: 60, y: 60),
                                            color: .systemBlue,
                                            lineWidth: 3)
        let rendered = AnnotationRenderer.render(image: source, annotations: [annotation])
        XCTAssertNotNil(rendered)
        XCTAssertEqual(rendered?.width, 100)
        XCTAssertEqual(rendered?.height, 100)
    }

    func testGIFEncoderWritesPlayableGIF() throws {
        let first = makeImage(width: 40, height: 30, color: .systemRed)
        let second = makeImage(width: 40, height: 30, color: .systemBlue)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacShotKit-test-\(UUID().uuidString).gif")
        defer { try? FileManager.default.removeItem(at: url) }

        try GIFEncoder.write(frames: [
            (first, CMTime(value: 0, timescale: 10)),
            (second, CMTime(value: 1, timescale: 10))
        ], maxWidth: 40, to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 20)
        XCTAssertEqual(Array(data.prefix(3)), [0x47, 0x49, 0x46]) // GIF
    }

    private func makeImage(width: Int, height: Int, color: NSColor) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
}
