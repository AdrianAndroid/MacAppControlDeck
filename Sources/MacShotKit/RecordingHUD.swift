import AppKit

final class RecordingHUDController {
    static let shared = RecordingHUDController()

    private var panel: NSPanel?
    private var timer: Timer?
    private var startedAt = Date()
    private var timeLabel: NSTextField?
    private var stopHandler: (() -> Void)?

    func show(format: RecordingFormat, onStop: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(format: format, onStop: onStop)
            }
            return
        }
        hide()
        startedAt = Date()
        stopHandler = onStop

        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 210, height: 54),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.78)
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true

        let content = NSView(frame: CGRect(x: 0, y: 0, width: 210, height: 54))
        let dot = NSView(frame: CGRect(x: 14, y: 23, width: 8, height: 8))
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dot.layer?.cornerRadius = 4
        content.addSubview(dot)

        let title = NSTextField(labelWithString: format == .gif ? "GIF 录制中" : "录屏中")
        title.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        title.textColor = .white
        title.frame = CGRect(x: 28, y: 17, width: 74, height: 18)
        content.addSubview(title)

        let time = NSTextField(labelWithString: "00:00")
        time.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        time.textColor = NSColor.white.withAlphaComponent(0.82)
        time.frame = CGRect(x: 102, y: 17, width: 48, height: 18)
        content.addSubview(time)
        timeLabel = time

        let stop = NSButton(title: "停止", target: self, action: #selector(stopTapped))
        stop.bezelStyle = .rounded
        stop.controlSize = .small
        stop.frame = CGRect(x: 154, y: 12, width: 48, height: 28)
        content.addSubview(stop)

        panel.contentView = content
        let visible = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(CGPoint(x: visible.midX - 105, y: visible.maxY - 70))
        panel.orderFrontRegardless()
        self.panel = panel

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func update(format: RecordingFormat) {
        // 预留：格式切换时可直接更新标题；当前标题在 show 时确定。
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        stopHandler = nil
        timeLabel = nil
    }

    @objc private func stopTapped() {
        stopHandler?()
    }

    private func tick() {
        let seconds = Int(Date().timeIntervalSince(startedAt))
        timeLabel?.stringValue = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
