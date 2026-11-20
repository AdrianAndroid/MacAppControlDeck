import AppKit
import ImageIO
import UniformTypeIdentifiers

enum ArrowStyle: String, CaseIterable, Identifiable {
    case single, thick, double, open, tail
    var id: String { rawValue }
    var title: String {
        switch self {
        case .single: return "单箭头"
        case .thick: return "粗箭头"
        case .double: return "双箭头"
        case .open: return "开放式"
        case .tail: return "尾羽"
        }
    }
}

enum ShapeFillMode: String, CaseIterable, Identifiable {
    case stroke, fill, strokeAndFill
    var id: String { rawValue }
    var title: String {
        switch self {
        case .stroke: return "描边"
        case .fill: return "填充"
        case .strokeAndFill: return "描边+填充"
        }
    }
}

enum TextAlign: String, CaseIterable, Identifiable {
    case left, center, right
    var id: String { rawValue }
    var title: String {
        switch self {
        case .left: return "左对齐"
        case .center: return "居中"
        case .right: return "右对齐"
        }
    }
}

enum CaptureTool: String, CaseIterable, Identifiable {
    case select
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
    case loupe
    case stamp
    case eyedropper
    case crop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "选择"
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
        case .loupe: return "放大镜"
        case .stamp: return "印章"
        case .eyedropper: return "取色"
        case .crop: return "裁剪"
        }
    }

    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
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
        case .loupe: return "magnifyingglass"
        case .stamp: return "face.smiling"
        case .eyedropper: return "eyedropper"
        case .crop: return "crop"
        }
    }

    var createsAnnotation: Bool {
        switch self {
        case .select, .eyedropper, .crop: return false
        default: return true
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

    // Advanced styles
    var arrowStyle: ArrowStyle = .single
    var arrowReversed = false
    var fillMode: ShapeFillMode = .stroke
    var cornerRadius: CGFloat = 0
    var rotation: CGFloat = 0
    var textBold = true
    var textItalic = false
    var textUnderline = false
    var textStrikethrough = false
    var textAlign: TextAlign = .left
    var textBackground = false
    var textBackgroundColor: NSColor = .black
    var stampEmoji: String = "😀"
    var loupeZoom: CGFloat = 2

    var unrotatedBounds: CGRect {
        if !points.isEmpty {
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            return CGRect(x: xs.min() ?? 0, y: ys.min() ?? 0,
                          width: (xs.max() ?? 0) - (xs.min() ?? 0),
                          height: (ys.max() ?? 0) - (ys.min() ?? 0))
                .insetBy(dx: -lineWidth, dy: -lineWidth)
        }
        var r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                       width: abs(end.x - start.x), height: abs(end.y - start.y))
        if tool == .text, let text, !text.isEmpty {
            let width = AnnotationRenderer.textSize(text, annotation: self).width
            r.size.width = max(r.width, width)
            r.size.height = max(r.height, fontSize * 1.3)
        }
        if tool == .stamp {
            r.size.width = max(r.width, fontSize * 1.6)
            r.size.height = max(r.height, fontSize * 1.6)
        }
        if tool == .number {
            let d = max(14, fontSize * 0.9) * 2
            r = CGRect(x: start.x - d / 2, y: start.y - d / 2, width: d, height: d)
        }
        return r.insetBy(dx: -lineWidth, dy: -lineWidth)
    }

    var boundingRect: CGRect {
        let r = unrotatedBounds
        guard rotation != 0 else { return r }
        let center = CGPoint(x: r.midX, y: r.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotation)
            .translatedBy(x: -center.x, y: -center.y)
        return r.applying(transform)
    }

    mutating func move(by delta: CGPoint) {
        start.x += delta.x; start.y += delta.y
        end.x += delta.x; end.y += delta.y
        points = points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
    }

    mutating func resize(to rect: CGRect) {
        let old = unrotatedBounds
        guard old.width > 1, old.height > 1 else {
            start = rect.origin; end = CGPoint(x: rect.maxX, y: rect.maxY); return
        }
        let sx = rect.width / old.width
        let sy = rect.height / old.height
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + (p.x - old.minX) * sx,
                    y: rect.minY + (p.y - old.minY) * sy)
        }
        start = map(start)
        end = map(end)
        points = points.map(map)
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

    static func resize(_ image: CGImage, width: Int, height: Int) -> CGImage {
        guard width > 0, height > 0,
              let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage() ?? image
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
