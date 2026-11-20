import AppKit

/// Pixel-parity port of macshot/UI/Overlay/RecordingHUDPanel.swift:
/// 164×32 borderless non-activating panel, 10pt corner radius, 32pt height,
/// 24pt stop/pause buttons, red dot + 13pt monospaced timer, 20pt drag handle.
final class RecordingHUDController {
    static let shared = RecordingHUDController()

    private var panel: NSPanel?
    private var container: HUDContainerView?
    private var timer: Timer?
    private var startedAt = Date()
    private var accumulatedPause: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var isPaused = false
    private var timeLabel: NSTextField?
    private var recordDot: NSTextField?
    private var stopButton: NSButton?
    private var pauseButton: NSButton?
    private var stopHandler: (() -> Void)?
    private var pauseHandler: ((Bool) -> Void)?

    private var borderWindow: NSWindow?
    private let hudHeight: CGFloat = 32
    private let cornerRadius: CGFloat = 10
    private let totalWidth: CGFloat = 164

    func show(format: RecordingFormat,
              relativeTo screenRect: CGRect? = nil,
              screen: NSScreen? = nil,
              onTogglePause: ((Bool) -> Void)? = nil,
              onStop: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.show(format: format, relativeTo: screenRect, screen: screen,
                           onTogglePause: onTogglePause, onStop: onStop)
            }
            return
        }
        hide()
        _ = format
        startedAt = Date()
        accumulatedPause = 0
        pauseStartedAt = nil
        isPaused = false
        stopHandler = onStop
        pauseHandler = onTogglePause

        if let screenRect {
            showBorder(around: screenRect)
        }

        let panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: totalWidth, height: hudHeight),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar + 2
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let container = HUDContainerView(frame: CGRect(x: 0, y: 0, width: totalWidth, height: hudHeight))
        container.wantsLayer = true
        container.panel = panel
        container.layer?.cornerRadius = cornerRadius
        container.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.94).cgColor
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.white.withAlphaComponent(0.1).cgColor
        panel.contentView = container

        let stop = HUDButton()
        stop.bezelStyle = .regularSquare
        stop.isBordered = false
        stop.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
        stop.contentTintColor = .white
        stop.imageScaling = .scaleProportionallyDown
        stop.target = self
        stop.action = #selector(stopClicked)
        stop.toolTip = "停止录制"
        stop.frame = CGRect(x: 6, y: 4, width: 24, height: 24)
        container.addSubview(stop)
        stopButton = stop

        let pause = HUDButton()
        pause.bezelStyle = .regularSquare
        pause.isBordered = false
        pause.contentTintColor = .white
        pause.imageScaling = .scaleProportionallyDown
        pause.target = self
        pause.action = #selector(pauseClicked)
        pause.toolTip = "暂停"
        pause.frame = CGRect(x: 32, y: 4, width: 24, height: 24)
        container.addSubview(pause)
        pauseButton = pause
        updatePauseIcon()

        let dot = NSTextField(labelWithString: "●")
        dot.font = .systemFont(ofSize: 11, weight: .bold)
        dot.textColor = .systemRed
        dot.isBezeled = false
        dot.drawsBackground = false
        dot.isEditable = false
        dot.sizeToFit()
        dot.frame.origin = CGPoint(x: 62, y: (hudHeight - dot.frame.height) / 2)
        container.addSubview(dot)
        recordDot = dot

        let time = NSTextField(labelWithString: "00:00")
        time.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        time.textColor = .white
        time.isBezeled = false
        time.drawsBackground = false
        time.isEditable = false
        time.sizeToFit()
        time.frame.origin = CGPoint(x: dot.frame.maxX + 3, y: (hudHeight - time.frame.height) / 2)
        container.addSubview(time)
        timeLabel = time

        let drag = NSImageView()
        drag.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Drag")?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .medium))
        drag.contentTintColor = NSColor.white.withAlphaComponent(0.35)
        drag.imageScaling = .scaleProportionallyDown
        drag.frame = CGRect(x: totalWidth - 20 - 6, y: (hudHeight - 16) / 2, width: 20, height: 16)
        container.addSubview(drag)

        panel.setFrameOrigin(position(for: screenRect, screen: screen, size: panel.frame.size))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.container = container

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// 需要从录屏像素里排除的窗口（HUD 与录制边框）。
    var windowNumbers: [CGWindowID] {
        [panel?.windowNumber, borderWindow?.windowNumber].compactMap { $0 }.map { CGWindowID($0) }
    }

    func update(format: RecordingFormat) {
        _ = format
    }

    private func showBorder(around rect: CGRect) {
        borderWindow?.orderOut(nil)
        let w = NSWindow(contentRect: rect, styleMask: .borderless,
                         backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.level = .statusBar + 1
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.isReleasedWhenClosed = false
        let view = RecordingBorderView(frame: CGRect(origin: .zero, size: rect.size))
        w.contentView = view
        w.orderFrontRegardless()
        borderWindow = w
    }

    func hide() {
        borderWindow?.orderOut(nil)
        borderWindow = nil
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        panel = nil
        container = nil
        stopHandler = nil
        pauseHandler = nil
        timeLabel = nil
        recordDot = nil
        stopButton = nil
        pauseButton = nil
        pauseStartedAt = nil
        isPaused = false
    }

    @objc private func stopClicked() {
        stopHandler?()
    }

    @objc private func pauseClicked() {
        isPaused.toggle()
        if isPaused {
            pauseStartedAt = Date()
            recordDot?.textColor = .systemOrange
            pauseButton?.toolTip = "继续录制"
        } else {
            if let pauseStartedAt {
                accumulatedPause += Date().timeIntervalSince(pauseStartedAt)
            }
            pauseStartedAt = nil
            recordDot?.textColor = .systemRed
            pauseButton?.toolTip = "暂停"
        }
        updatePauseIcon()
        tick()
        pauseHandler?(isPaused)
    }

    private func updatePauseIcon() {
        let name = isPaused ? "play.fill" : "pause.fill"
        pauseButton?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
    }

    private func tick() {
        var elapsed = Date().timeIntervalSince(startedAt) - accumulatedPause
        if let pauseStartedAt {
            elapsed -= Date().timeIntervalSince(pauseStartedAt)
        }
        let seconds = max(0, Int(elapsed))
        timeLabel?.stringValue = String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func position(for rect: CGRect?, screen: NSScreen?, size: NSSize) -> CGPoint {
        guard let rect else {
            let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
            return CGPoint(x: visible.maxX - size.width - 8, y: visible.maxY - size.height - 8)
        }
        let visible = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = rect.maxX - size.width - 8
        var y = rect.maxY + 8
        if y + size.height > visible.maxY {
            y = rect.minY - size.height - 8
        }
        x = max(visible.minX + 4, min(x, visible.maxX - size.width - 4))
        y = max(visible.minY + 4, min(y, visible.maxY - size.height - 4))
        return CGPoint(x: x, y: y)
    }
}

private final class HUDContainerView: NSView {
    weak var panel: NSPanel?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let sepX = bounds.width - 30
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let separator = NSBezierPath()
        separator.move(to: CGPoint(x: sepX, y: 6))
        separator.line(to: CGPoint(x: sepX, y: bounds.height - 6))
        separator.lineWidth = 0.5
        separator.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if point.x >= bounds.width - 28 {
            panel?.performDrag(with: event)
        }
    }

    override func resetCursorRects() {
        addCursorRect(CGRect(x: bounds.width - 28, y: 0, width: 28, height: bounds.height),
                      cursor: .openHand)
    }
}


private final class RecordingBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.95).setStroke()
        let path = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        path.lineWidth = 2.5
        path.stroke()
    }
}

/// HUD 是非激活面板；默认 NSButton 会吞掉第一次点击，导致停止按钮“点一下没反应”。
private final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class HUDButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
