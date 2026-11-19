import AppKit

/// 截图完成后的轻提示，不抢焦点、不弹模态框。
enum CaptureToast {
    static func show(_ text: String) {
        let width: CGFloat = 360
        let height: CGFloat = 44
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.material = .hudWindow
        container.state = .active
        container.blendingMode = .behindWindow
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        label.frame = container.bounds.insetBy(dx: 16, dy: 10)
        label.autoresizingMask = [.width, .height]
        container.addSubview(label)
        panel.contentView = container

        if let screen = (NSScreen.main ?? NSScreen.screens.first) {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - width / 2,
                                         y: screen.visibleFrame.minY + 80))
        }
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            panel.close()
        }
    }
}
