import AppKit
import ImageIO
import UniformTypeIdentifiers

enum CaptureTool: String, CaseIterable, Identifiable {
    case rectangle
    case filledRectangle
    case ellipse
    case line
    case arrow
    case pen
    case marker
    case text
    case number
    case pixelate
    case blur
    case highlight
    case measure
    case crop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rectangle: return "矩形"
        case .filledRectangle: return "实心矩形"
        case .ellipse: return "椭圆"
        case .line: return "直线"
        case .arrow: return "箭头"
        case .pen: return "画笔"
        case .marker: return "荧光笔"
        case .text: return "文字"
        case .number: return "序号"
        case .pixelate: return "马赛克"
        case .blur: return "模糊打码"
        case .highlight: return "聚光灯"
        case .measure: return "测量"
        case .crop: return "裁剪"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "rectangle"
        case .filledRectangle: return "rectangle.fill"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .pen: return "pencil"
        case .marker: return "highlighter"
        case .text: return "textformat"
        case .number: return "1.circle"
        case .pixelate: return "square.grid.3x3.fill"
        case .blur: return "drop.fill"
        case .highlight: return "flashlight.on.fill"
        case .measure: return "ruler"
        case .crop: return "crop"
        }
    }
}

struct CaptureAnnotation: Identifiable {
    var id = UUID()
    var tool: CaptureTool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint] = []
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 3
    var text: String?
    var number: Int?
    var fontSize: CGFloat = 22
    var alpha: CGFloat = 1

    var boundingRect: CGRect {
        if !points.isEmpty {
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                          width: (xs.max() ?? 0) - (xs.min() ?? 0),
                          height: (ys.max() ?? 0) - (ys.min() ?? 0))
                .insetBy(dx: -lineWidth, dy: -lineWidth)
        }
        return CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                      width: abs(end.x - start.x), height: abs(end.y - start.y))
            .insetBy(dx: -lineWidth, dy: -lineWidth)
    }
}

enum CaptureExporter {
    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try write(image, to: url, format: "png", quality: 1)
    }

    static func write(_ image: CGImage,
                      to url: URL,
                      format: String,
                      quality: Double) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let type: UTType
        switch format {
        case "jpeg", "jpg": type = .jpeg
        case "heic": type = .heic
        case "webp": type = UTType(filenameExtension: "webp") ?? .png
        case "avif": type = UTType(filenameExtension: "avif") ?? .png
        default: type = .png
        }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, type.identifier as CFString, 1, nil
        ) else { throw ExportError.encodeFailed }
        var properties: [CFString: Any] = [:]
        if type != .png {
            properties[kCGImageDestinationLossyCompressionQuality] = max(0.05, min(quality, 1))
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.encodeFailed }
    }

    static func copyToPasteboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image,
                              size: NSSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
    }

    enum ExportError: LocalizedError {
        case encodeFailed
        var errorDescription: String? { "图片编码失败" }
    }
}
