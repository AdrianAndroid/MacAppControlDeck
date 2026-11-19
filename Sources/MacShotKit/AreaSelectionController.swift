import AppKit

/// 多屏区域选择。只负责“拿到一个屏幕全局矩形”，不碰截图、不碰编辑器。
final class AreaSelectionController {
    static let shared = AreaSelectionController()

    private var windows: [SelectionWindow] = []
    private var completion: ((NSScreen, CGRect) -> Void)?
    private var escapeMonitor: Any?

    var isActive: Bool { !windows.isEmpty }

    func begin(completion: @escaping (NSScreen, CGRect) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion

        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = SelectionWindow(screen: screen)
            let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.controller = self
            view.screen = screen
            window.contentView = view
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
        }

        // borderless window 的 keyDown 在个别输入法下不稳定，补一个本地兜底。
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.cancel()
            return nil
        }
    }

    fileprivate func committed(screen: NSScreen, rect: CGRect) {
        guard let completion else { return }
        finish()
        completion(screen, rect)
    }

    func cancel() {
        finish()
    }

    private func finish() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        completion = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private final class SelectionWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    weak var controller: AreaSelectionController?
    var screen: NSScreen?

    private var anchor: NSPoint?
    private var current: NSPoint?
    private var isDragging = false

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        anchor = point
        current = point
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let anchor, let screen else { return }
        isDragging = false
        let point = convert(event.locationInWindow, from: nil)
        let localRect = CGRect(x: min(anchor.x, point.x),
                               y: min(anchor.y, point.y),
                               width: abs(point.x - anchor.x),
                               height: abs(point.y - anchor.y))
        guard localRect.width >= 8, localRect.height >= 8 else {
            self.anchor = nil
            current = nil
            needsDisplay = true
            return
        }
        let globalRect = CGRect(x: screen.frame.minX + localRect.minX,
                                y: screen.frame.minY + localRect.minY,
                                width: localRect.width,
                                height: localRect.height)
        controller?.committed(screen: screen, rect: globalRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            controller?.cancel()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
        context.fill(bounds)

        guard let rect = selectionRect else {
            drawHint()
            return
        }

        // 清空选区，让原始屏幕透出来。
        context.saveGState()
        context.setBlendMode(.clear)
        context.fill(rect)
        context.restoreGState()

        // 选区边框 + 四角手柄。
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        NSColor.controlAccentColor.setStroke()
        border.lineWidth = 1.5
        border.stroke()

        let handle: CGFloat = 6
        let points = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY)
        ]
        for point in points {
            let handleRect = CGRect(x: point.x - handle / 2,
                                    y: point.y - handle / 2,
                                    width: handle, height: handle)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2).fill()
        }

        // 尺寸标签。
        let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (sizeText as NSString).size(withAttributes: attributes)
        let labelRect = CGRect(x: rect.maxX - textSize.width - 14,
                               y: max(rect.maxY + 8, 8),
                               width: textSize.width + 14,
                               height: textSize.height + 6)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5).fill()
        (sizeText as NSString).draw(at: CGPoint(x: labelRect.minX + 7, y: labelRect.minY + 3),
                                    withAttributes: attributes)

        drawHint()
    }

    private var selectionRect: CGRect? {
        guard let anchor, let current else { return nil }
        return CGRect(x: min(anchor.x, current.x),
                      y: min(anchor.y, current.y),
                      width: abs(current.x - anchor.x),
                      height: abs(current.y - anchor.y))
    }

    private func drawHint() {
        let text = "拖动选择区域  ·  Esc 取消"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: (bounds.width - size.width) / 2 - 12,
                          y: bounds.height - 70,
                          width: size.width + 24,
                          height: size.height + 12)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 6),
                                withAttributes: attributes)
    }
}
