import AppKit

/// 钉剪贴板内容：图片、文件 URL、富文本（RTF/HTML）与纯文本都能钉成浮窗。
/// 简化自上游 ClipboardPinService + ClipboardTextPinRenderer。
public enum ClipboardPinService {
    static let maxCharacters = 20_000
    private static let padding = NSEdgeInsets(top: 22, left: 24, bottom: 22, right: 24)
    private static let plainFont = NSFont.monospacedSystemFont(ofSize: 18, weight: .regular)

    @discardableResult
    public static func pinClipboard() -> Bool {
        let pasteboard = NSPasteboard.general

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url),
                   let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    PinWindowController.shared.pin(cg)
                    return true
                }
            }
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            PinWindowController.shared.pin(cg)
            return true
        }
        if let attributed = attributedFromPasteboard(pasteboard) {
            guard let rendered = render(attributed) else { return false }
            PinWindowController.shared.pin(rendered)
            return true
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let attributed = plainAttributedString(truncate(text))
            guard let rendered = render(attributed) else { return false }
            PinWindowController.shared.pin(rendered)
            return true
        }
        MacShotController.shared.showToast("剪贴板里没有可钉的内容")
        return false
    }

    /// 把剪贴板里的富文本/纯文本渲染成图片，供编辑器「粘贴为图片图层」使用。
    static func renderedClipboardContent() -> CGImage? {
        let pasteboard = NSPasteboard.general
        if let attributed = attributedFromPasteboard(pasteboard) {
            return render(attributed)
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return render(plainAttributedString(truncate(text)))
        }
        return nil
    }

    private static func attributedFromPasteboard(_ pasteboard: NSPasteboard) -> NSAttributedString? {
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
            data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil) {
            return truncate(attributed)
        }
        if let html = pasteboard.data(forType: .html),
           let attributed = try? NSAttributedString(
            data: html, options: [.documentType: NSAttributedString.DocumentType.html,
                                  .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil) {
            return truncate(attributed)
        }
        return nil
    }

    private static func truncate(_ text: String) -> String {
        guard text.count > maxCharacters else { return text }
        return String(text.prefix(maxCharacters)) + "\n…"
    }

    private static func truncate(_ attributed: NSAttributedString) -> NSAttributedString {
        guard attributed.length > maxCharacters else { return attributed }
        let boundary = (attributed.string as NSString)
            .rangeOfComposedCharacterSequence(at: maxCharacters).location
        let clipped = NSMutableAttributedString(attributedString:
            attributed.attributedSubstring(from: NSRange(location: 0, length: boundary)))
        clipped.append(NSAttributedString(string: "\n…"))
        return clipped
    }

    private static func plainAttributedString(_ string: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left
        return NSAttributedString(string: string, attributes: [
            .font: plainFont,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ])
    }

    static func render(_ attributed: NSAttributedString) -> CGImage? {
        guard attributed.length > 0 else { return nil }
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let maxWidth = max(320, min(980, screen.width * 0.72))
        let maxHeight = max(240, screen.height * 0.82)

        let mutable = NSMutableAttributedString(attributedString: attributed)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.paragraphStyle, in: fullRange) { value, range, _ in
            let paragraph = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            mutable.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }

        let bounding = mutable.boundingRect(
            with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let contentSize = CGSize(width: ceil(bounding.width), height: ceil(bounding.height))
        guard contentSize.width > 0, contentSize.height > 0 else { return nil }

        let width = contentSize.width + padding.left + padding.right
        let height = min(contentSize.height + padding.top + padding.bottom, maxHeight)

        let image = NSImage(size: CGSize(width: width, height: height))
        image.lockFocus()
        NSColor.white.setFill()
        CGRect(x: 0, y: 0, width: width, height: height).fill()
        mutable.draw(with: CGRect(x: padding.left, y: padding.bottom,
                                  width: contentSize.width, height: contentSize.height),
                     options: [.usesLineFragmentOrigin, .usesFontLeading])
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cg = rep.cgImage else { return nil }
        return cg
    }
}
