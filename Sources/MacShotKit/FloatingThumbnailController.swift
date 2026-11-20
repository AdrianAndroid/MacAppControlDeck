import AppKit

/// 保存/复制后的悬浮缩略图（对应上游 FloatingThumbnailController 的核心交互）：
/// 点击进入编辑器，拖出得到文件，悬停显示关闭，5 秒后自动收起。
final class FloatingThumbnailController {
    static let shared = FloatingThumbnailController()

    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?
    private var image: CGImage?
    private var fileURL: URL?

    private init() {}

    func show(image: CGImage, fileURL: URL?) {
        dismiss()
        self.image = image
        self.fileURL = fileURL

        let thumbWidth: CGFloat = 168
        let aspect = CGFloat(image.height) / max(CGFloat(image.width), 1)
        let thumbHeight = min(round(thumbWidth * aspect), 220)
        let footer: CGFloat = 22
        let padding: CGFloat = 8
        let panelSize = CGSize(width: thumbWidth, height: thumbHeight + footer + padding * 2)

        let content = ThumbnailContentView(image: image, fileURL: fileURL)
        content.frame = CGRect(origin: .zero, size: panelSize)
        content.onClick = { [weak self] in
            guard let self, let image = self.image else { return }
            self.dismiss()
            CaptureEditorWindowController.shared.show(image: image)
        }
        content.onClose = { [weak self] in self?.dismiss() }

        let panel = ThumbnailPanel(contentRect: CGRect(origin: .zero, size: panelSize),
                                   styleMask: [.borderless, .nonactivatingPanel],
                                   backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.contentView = content
        panel.setFrameOrigin(origin(for: panelSize))
        panel.orderFrontRegardless()
        self.panel = panel

        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    func dismiss() {
        dismissWork?.cancel()
        dismissWork = nil
        panel?.orderOut(nil)
        panel = nil
        image = nil
        fileURL = nil
    }

    private func origin(for size: CGSize) -> CGPoint {
        let screen = NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let screenFrame = screen?.frame ?? visible
        return CGPoint(x: screenFrame.maxX - size.width - 24,
                       y: visible.minY + 40)
    }
}

private final class ThumbnailPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class ThumbnailContentView: NSView, NSDraggingSource {
    private let image: CGImage
    private let fileURL: URL?
    private let imageView = NSImageView()
    private let closeButton = NSButton()
    private var mouseDownPoint: CGPoint?
    private var dragging = false
    private var hover = false
    private var tracking: NSTrackingArea?
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?

    init(image: CGImage, fileURL: URL?) {
        self.image = image
        self.fileURL = fileURL
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.95).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor

        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "关闭")
        closeButton.contentTintColor = .white
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        closeButton.isHidden = true
        addSubview(closeButton)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let pad: CGFloat = 8
        let footer: CGFloat = 22
        imageView.frame = CGRect(x: pad, y: pad + footer, width: bounds.width - pad * 2,
                                 height: bounds.height - pad * 2 - footer)
        closeButton.frame = CGRect(x: bounds.width - 26, y: bounds.height - 26, width: 18, height: 18)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }

    private func setHover(_ value: Bool) {
        hover = value
        closeButton.isHidden = !value
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, !dragging else { return }
        let p = convert(event.locationInWindow, from: nil)
        guard hypot(p.x - start.x, p.y - start.y) > 4 else { return }
        dragging = true
        let item = NSPasteboardItem()
        if let fileURL {
            item.setString(fileURL.absoluteString, forType: .fileURL)
        }
        if let tiff = NSBitmapImageRep(cgImage: image).representation(using: .tiff, properties: [:]) {
            item.setData(tiff, forType: .tiff)
        }
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        let preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        draggingItem.setDraggingFrame(CGRect(x: p.x - 60, y: p.y - 40, width: 120, height: 80),
                                      contents: preview)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
        onClose?()
    }

    override func mouseUp(with event: NSEvent) {
        guard !dragging else { dragging = false; return }
        if let start = mouseDownPoint {
            let p = convert(event.locationInWindow, from: nil)
            if hypot(p.x - start.x, p.y - start.y) < 4 { onClick?() }
        }
        mouseDownPoint = nil
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    @objc private func closeTapped() { onClose?() }
}
