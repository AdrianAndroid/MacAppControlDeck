import AppKit
import UniformTypeIdentifiers

/// 图片导出：按设置写文件并复制剪贴板（供保存链路与旧代码共用）。
enum CaptureExporter {
    static func write(_ image: CGImage, to url: URL,
                      format: String = "png", quality: Double = 1.0) throws {
        let type: UTType
        switch format.lowercased() {
        case "jpeg", "jpg": type = .jpeg
        case "heic": type = .jpeg
        case "tiff": type = .tiff
        case "bmp": type = .bmp
        case "gif": type = .gif
        default: type = .png
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: bitmapType(for: type), properties: [:]) else {
            throw NSError(domain: "CaptureExporter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "图片编码失败"])
        }
        try data.write(to: url, options: .atomic)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try write(image, to: url, format: "png")
    }

    static func copyToPasteboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))])
    }

    static func pngData(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }

    private static func bitmapType(for type: UTType) -> NSBitmapImageRep.FileType {
        switch type {
        case .jpeg: return .jpeg
        case .heic: return .jpeg
        case .tiff: return .tiff
        case .bmp: return .bmp
        case .gif: return .gif
        default: return .png
        }
    }
}
