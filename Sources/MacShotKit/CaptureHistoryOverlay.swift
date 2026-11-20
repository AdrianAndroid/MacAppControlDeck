import AppKit

/// 截图历史浮层：缩略图网格浏览、点击重编辑、右键复制/OCR/钉图/删除。
/// 对应上游 HistoryOverlayController 的核心体验，不涉及上传或账号。
public final class CaptureHistoryOverlayController {
    public static let shared = CaptureHistoryOverlayController()

    private var window: NSWindow?
    private var grid: HistoryGridView?

    private init() {}

    public func show() {
        if let window {
            grid?.reload()
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let size = CGSize(width: 880, height: 560)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "截图历史"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 520, height: 360)

        let scroll = NSScrollView(frame: CGRect(origin: .zero, size: size))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autoresizingMask = [.width, .height]
        let grid = HistoryGridView(frame: CGRect(origin: .zero, size: size))
        scroll.documentView = grid
        window.contentView = scroll

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        self.grid = grid
        grid.reload()
    }

    public func dismiss() {
        window?.orderOut(nil)
        window = nil
        grid = nil
    }
}

private final class HistoryGridView: NSView {
    private struct Item {
        let url: URL
        let image: NSImage
        var rect: CGRect
    }

    private var items: [Item] = []
    private var hoverIndex: Int?
    private var tracking: NSTrackingArea?
    private let cardWidth: CGFloat = 200
    private let cardHeight: CGFloat = 160
    private let gap: CGFloat = 16
    private let pad: CGFloat = 18

    override var isFlipped: Bool { true }

    func reload() {
        items = []
        let urls = CaptureHistoryStore.shared.urls
        for url in urls {
            guard items.count < 60 else { break }
            guard let image = Self.thumbnail(url: url) else { continue }
            items.append(Item(url: url, image: image, rect: .zero))
        }
        layoutCards()
        needsDisplay = true
    }

    private static func thumbnail(url: URL) -> NSImage? {
        guard let source = NSImage(contentsOf: url) else { return nil }
        let maxSide: CGFloat = 320
        let scale = min(maxSide / max(source.size.width, 1),
                        maxSide / max(source.size.height, 1), 1)
        let size = CGSize(width: max(1, source.size.width * scale),
                          height: max(1, source.size.height * scale))
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        source.draw(in: CGRect(origin: .zero, size: size))
        thumb.unlockFocus()
        return thumb
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutCards()
    }

    private func layoutCards() {
        let width = max(bounds.width, cardWidth)
        let columns = max(1, Int((width - pad * 2 + gap) / (cardWidth + gap)))
        for index in items.indices {
            let row = index / columns
            let column = index % columns
            items[index].rect = CGRect(x: pad + CGFloat(column) * (cardWidth + gap),
                                       y: pad + CGFloat(row) * (cardHeight + gap),
                                       width: cardWidth, height: cardHeight)
        }
        let rows = (items.count + columns - 1) / columns
        let height = pad * 2 + CGFloat(rows) * (cardHeight + gap)
        if abs(frame.height - height) > 1 {
            setFrameSize(CGSize(width: bounds.width, height: max(height, superview?.bounds.height ?? height)))
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let index = items.firstIndex { $0.rect.contains(p) }
        if index != hoverIndex { hoverIndex = index; needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) {
        hoverIndex = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let index = items.firstIndex(where: { $0.rect.contains(p) }) else { return }
        if event.clickCount >= 2 {
            openInFinder(items[index].url)
        } else {
            openInEditor(items[index].url)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let index = items.firstIndex(where: { $0.rect.contains(p) }) else { return }
        let url = items[index].url
        let menu = NSMenu()
        menu.addItem(menuItem("在编辑器中打开", #selector(menuOpenEditor(_:)), url))
        menu.addItem(menuItem("复制图片", #selector(menuCopy(_:)), url))
        menu.addItem(menuItem("OCR 识别", #selector(menuOCR(_:)), url))
        menu.addItem(menuItem("钉在屏幕上", #selector(menuPin(_:)), url))
        menu.addItem(.separator())
        menu.addItem(menuItem("在 Finder 中显示", #selector(menuReveal(_:)), url))
        menu.addItem(menuItem("删除", #selector(menuDelete(_:)), url))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func menuItem(_ title: String, _ action: Selector, _ url: URL) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = url
        return item
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        for (index, item) in items.enumerated() {
            let card = item.rect
            let path = NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10)
            (hoverIndex == index ? NSColor.controlAccentColor.withAlphaComponent(0.18)
                                 : NSColor.controlBackgroundColor).setFill()
            path.fill()

            let imageRect = card.insetBy(dx: 8, dy: 8).insetBy(dx: 0, dy: 14)
            let image = item.image
            let scale = min(imageRect.width / max(image.size.width, 1),
                            imageRect.height / max(image.size.height, 1))
            let drawSize = CGSize(width: image.size.width * scale,
                                  height: image.size.height * scale)
            let drawRect = CGRect(x: imageRect.midX - drawSize.width / 2,
                                  y: imageRect.midY - drawSize.height / 2,
                                  width: drawSize.width, height: drawSize.height)
            image.draw(in: drawRect)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10.5),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let name = item.url.lastPathComponent as NSString
            name.draw(in: CGRect(x: card.minX + 10, y: card.maxY - 18,
                                 width: card.width - 20, height: 14),
                      withAttributes: attrs)
        }
        if items.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            ("暂无截图历史" as NSString).draw(at: CGPoint(x: bounds.midX - 50, y: 80),
                                          withAttributes: attrs)
        }
    }

    private func openInEditor(_ url: URL) {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        CaptureHistoryOverlayController.shared.dismiss()
        CaptureEditorWindowController.shared.show(image: cg)
    }

    private func openInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func menuOpenEditor(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        openInEditor(url)
    }

    @objc private func menuCopy(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    @objc private func menuOCR(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        OCRResultController.shared.recognize(cg)
    }

    @objc private func menuPin(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        PinWindowController.shared.pin(cg, at: nil)
    }

    @objc private func menuReveal(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func menuDelete(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        try? FileManager.default.removeItem(at: url)
        CaptureHistoryStore.shared.remove(url)
        reload()
    }
}
