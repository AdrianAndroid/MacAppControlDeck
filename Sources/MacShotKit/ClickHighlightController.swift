import AppKit

/// Draws a short ripple at every mouse-down while a recording is running.
final class ClickHighlightController {
    static let shared = ClickHighlightController()

    private var monitor: Any?
    private var panel: NSPanel?

    func start() {
        guard monitor == nil else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        panel.orderFrontRegardless()
        self.panel = panel

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let p = NSEvent.mouseLocation
            DispatchQueue.main.async { self?.showRipple(at: p) }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func showRipple(at global: CGPoint) {
        guard let panel, let content = panel.contentView else { return }
        let local = CGPoint(x: global.x - panel.frame.minX, y: global.y - panel.frame.minY)
        let size: CGFloat = 18
        let circle = NSView(frame: CGRect(x: local.x - size / 2, y: local.y - size / 2,
                                          width: size, height: size))
        circle.wantsLayer = true
        circle.layer?.cornerRadius = size / 2
        circle.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.9).cgColor
        circle.layer?.borderWidth = 2
        circle.layer?.borderColor = NSColor.black.withAlphaComponent(0.55).cgColor
        content.addSubview(circle)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            circle.animator().alphaValue = 0
            circle.animator().frame = circle.frame.insetBy(dx: -14, dy: -14)
            circle.layer?.cornerRadius = (size + 28) / 2
        } completionHandler: {
            circle.removeFromSuperview()
        }
    }
}
