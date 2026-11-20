import AppKit
import CoreGraphics
import CoreMedia
import ImageIO
import XCTest
import CoreVideo
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

    func testUpstreamGIFEncoderWritesPlayableGIF() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacShotKit-test-\(UUID().uuidString).gif")
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = try GIFEncoder(url: url)
        try encoder.addFrame(try makePixelBuffer(width: 40, height: 30, color: .systemRed),
                             at: CMTime(value: 0, timescale: 10))
        try encoder.addFrame(try makePixelBuffer(width: 40, height: 30, color: .systemBlue),
                             at: CMTime(value: 1, timescale: 10))
        try encoder.finish(at: CMTime(value: 2, timescale: 10))

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 20)
        XCTAssertEqual(Array(data.prefix(3)), [0x47, 0x49, 0x46]) // GIF
    }

    private func makePixelBuffer(width: Int, height: Int, color: NSColor) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true,
                                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let buffer else {
            throw NSError(domain: "test", code: 1)
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: width, height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                    | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw NSError(domain: "test", code: 2)
        }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
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
