import AppKit
import CoreGraphics

struct WindowCaptureTarget {
    let windowID: CGWindowID
    let ownerName: String
    let windowName: String
    let bounds: CGRect
}

/// 窗口拾取：鼠标悬停高亮，点击捕获该窗口。只返回目标，不抓图。
final class WindowSelectionController {
    static let shared = WindowSelectionController()

    private var windows: [WindowPickWindow] = []
    private var completion: ((WindowCaptureTarget) -> Void)?
    private var escapeMonitor: Any?
    private var candidates: [WindowCaptureTarget] = []

    func begin(completion: @escaping (WindowCaptureTarget) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion
        candidates = Self.windowCandidates()

        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let window = WindowPickWindow(screen: screen)
            let view = WindowPickView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.controller = self
            view.screen = screen
            view.candidates = candidates
            window.contentView = view
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            windows.append(window)
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.cancel()
            return nil
        }
    }

    fileprivate func committed(_ target: WindowCaptureTarget) {
        guard let completion else { return }
        finish()
        completion(target)
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
        candidates = []
    }

    private static func windowCandidates() -> [WindowCaptureTarget] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        var result: [WindowCaptureTarget] = []
        for info in list {
            guard let layer = info[kCGWindowLayer as String] as? NSNumber, layer.intValue == 0,
                  let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerPID.int32Value != ownPID,
                  let windowID = info[kCGWindowNumber as String] as? NSNumber,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width >= 60, bounds.height >= 60,
                  bounds.width < 20000, bounds.height < 20000,
                  let alpha = info[kCGWindowAlpha as String] as? NSNumber, alpha.doubleValue > 0.05
            else { continue }

            let owner = info[kCGWindowOwnerName as String] as? String ?? ""
            let name = info[kCGWindowName as String] as? String ?? ""
            if owner == "Window Server" || owner == "Dock" { continue }
            result.append(WindowCaptureTarget(windowID: CGWindowID(windowID.uint32Value),
                                              ownerName: owner,
                                              windowName: name,
                                              bounds: bounds))
        }
        return result
    }
}

private final class WindowPickWindow: NSWindow {
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

private final class WindowPickView: NSView {
    weak var controller: WindowSelectionController?
    var screen: NSScreen?
    var candidates: [WindowCaptureTarget] = []
    private var highlighted: WindowCaptureTarget?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = event.locationInWindow
        let origin = screen?.frame.origin ?? .zero
        let global = NSPoint(x: origin.x + point.x, y: origin.y + point.y)
        let topLeft = CaptureGeometry.globalTopLeftPoint(fromScreenPoint: global)
        let target = candidates.first { $0.bounds.contains(topLeft) }
        if target?.windowID != highlighted?.windowID {
            highlighted = target
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard let highlighted else { return }
        controller?.committed(highlighted)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            controller?.cancel()
        } else {
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current?.cgContext
        context?.setFillColor(NSColor.black.withAlphaComponent(0.18).cgColor)
        context?.fill(bounds)

        if let target = highlighted, let screen {
            let mainHeight = NSScreen.screens.first?.frame.height ?? 0
            let appKitY = mainHeight - target.bounds.maxY
            let local = CGRect(x: target.bounds.minX - screen.frame.minX,
                               y: appKitY - screen.frame.minY,
                               width: target.bounds.width,
                               height: target.bounds.height)
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(rect: local.insetBy(dx: 0.5, dy: 0.5))
            path.lineWidth = 3
            path.stroke()

            let label = target.windowName.isEmpty
                ? target.ownerName
                : "\(target.ownerName) — \(target.windowName)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = (label as NSString).size(withAttributes: attributes)
            let labelRect = CGRect(x: local.minX + 8,
                                   y: max(local.maxY - size.height - 12, 8),
                                   width: size.width + 18,
                                   height: size.height + 8)
            NSColor.black.withAlphaComponent(0.72).setFill()
            NSBezierPath(roundedRect: labelRect, xRadius: 6, yRadius: 6).fill()
            (label as NSString).draw(at: CGPoint(x: labelRect.minX + 9, y: labelRect.minY + 4),
                                     withAttributes: attributes)
        }

        let hint = "点击要截取的窗口  ·  Esc 取消"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (hint as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: (bounds.width - size.width) / 2 - 12,
                          y: bounds.height - 70,
                          width: size.width + 24,
                          height: size.height + 12)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        (hint as NSString).draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 6),
                                withAttributes: attributes)
    }
}
