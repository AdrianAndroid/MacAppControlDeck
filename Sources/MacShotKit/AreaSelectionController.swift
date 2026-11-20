import AppKit
import CoreGraphics

final class AreaSelectionController {
    static let shared = AreaSelectionController()

    private var window: SelectionWindow?
    private var view: SelectionView?
    private var completion: ((NSScreen, CGRect, CGImage?) -> Void)?
    private var escapeMonitor: Any?
    private var snapshot: CGImage?
    private var unionFrame: CGRect = .zero

    var isActive: Bool { window != nil }

    func begin(completion: @escaping (NSScreen, CGRect, CGImage?) -> Void) {
        guard window == nil else { return }
        self.completion = completion
        let frames = NSScreen.screens.map(\.frame)
        guard !frames.isEmpty else { return }
        unionFrame = frames.reduce(CGRect.null) { $0.union($1) }
        let image = ScreenCaptureService.captureAllScreensStitched()
        snapshot = image

        let window = SelectionWindow(contentRect: unionFrame)
        let view = SelectionView(frame: CGRect(origin: .zero, size: unionFrame.size))
        view.controller = self
        view.snapshot = image
        view.preset = MacShotController.shared.selectionPreset
        window.contentView = view
        window.setFrame(unionFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        self.window = window
        self.view = view

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window != nil else { return event }
            if event.keyCode == 53 { self.cancel(); return nil }
            return event
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func commit(rectGlobal: CGRect) {
        guard let completion else { return }
        let center = CGPoint(x: rectGlobal.midX, y: rectGlobal.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(rectGlobal) })
            ?? NSScreen.main
        guard let screen else { return }
        let snapshot = self.snapshot
        let image = snapshot?.croppedToGlobalRect(rectGlobal, union: unionFrame)
        finish()
        completion(screen, rectGlobal, image)
    }

    func cancel() { finish() }

    private func finish() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        completion = nil
        window?.orderOut(nil)
        window = nil
        view = nil
        snapshot = nil
    }
}

private enum SelectionHandleKind { case tl, tm, tr, ml, mr, bl, bm, br, none }

private final class SelectionWindow: NSWindow {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: .borderless,
                   backing: .buffered, defer: false)
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
    var snapshot: CGImage?
    var preset: CaptureSelectionPreset = .free

    private var rect: CGRect?
    private var anchor: CGPoint = .zero
    private var startRect: CGRect = .zero
    private var mode: Mode = .idle
    private var handle: SelectionHandleKind = .none
    private var unionFrame: CGRect = .zero
    private var mainMaxY: CGFloat = 0
    private var snapLines: (vertical: [CGFloat], horizontal: [CGFloat]) = ([], [])

    private enum Mode { case idle, creating, moving, resizing }

    // 原地编辑态（不再打开独立编辑窗口）
    private var editing = false
    private var toolbarButtons: [(title: String, rect: CGRect, action: String)] = []

    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        unionFrame = window.frame
        mainMaxY = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.maxY ?? unionFrame.maxY
        buildSnapLines()
    }

    private func buildSnapLines() {
        var vx: [CGFloat] = [0, bounds.width]
        var hy: [CGFloat] = [0, bounds.height]
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            snapLines = (vx, hy); return
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        for info in windows {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? Int, pid != ownPID,
                  let owner = info[kCGWindowOwnerName as String] as? String,
                  owner != "Window Server", owner != "Dock",
                  let dict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = dict["X"], let y = dict["Y"], let w = dict["Width"], let h = dict["Height"],
                  w > 20, h > 20 else { continue }
            let localX = x - unionFrame.minX
            let localY = (mainMaxY - y - h) - unionFrame.minY
            guard localX > -2, localY > -2,
                  localX < bounds.width + 2, localY < bounds.height + 2 else { continue }
            vx.append(contentsOf: [localX, localX + w])
            hy.append(contentsOf: [localY, localY + h])
        }
        snapLines = (vx, hy)
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if editing, let hit = toolbarButtons.first(where: { $0.rect.contains(p) }) {
            performToolbarAction(hit.action)
            return
        }
        anchor = p
        if let r = rect {
            if event.clickCount >= 2, r.contains(p) { commitCurrent(); return }
            let h = hitHandle(p, rect: r)
            if h != .none { mode = .resizing; handle = h; startRect = r; return }
            if r.insetBy(dx: -2, dy: -2).contains(p) { mode = .moving; startRect = r; return }
        }
        mode = .creating
        rect = CGRect(origin: p, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        var p = convert(event.locationInWindow, from: nil)
        if !event.modifierFlags.contains(.option) { p = snap(p) }
        switch mode {
        case .creating: rect = constrainedRect(anchor: anchor, current: p)
        case .moving:
            let dx = p.x - anchor.x, dy = p.y - anchor.y
            rect = clamp(startRect.offsetBy(dx: dx, dy: dy))
        case .resizing: rect = resize(startRect, handle: handle, to: p)
        case .idle: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        mode = .idle
        if let r = rect, r.width < 8 || r.height < 8 { rect = nil }
        if let r = rect, !editing, mode == .idle { editing = true; updateToolbar() }
        if let r = rect, case .pixels(_, let w, let h) = preset {
            let target = CGRect(x: r.minX, y: r.minY, width: CGFloat(w), height: CGFloat(h))
            rect = clamp(target)
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { controller?.cancel(); return }
        if event.keyCode == 36 || event.keyCode == 76 { commitCurrent(); return }
        if event.keyCode == 48 { cyclePreset(); return }
        if event.keyCode == 51 || event.keyCode == 117 { rect = nil; needsDisplay = true; return }
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        var d = CGPoint.zero
        switch event.keyCode {
        case 123: d.x = -step
        case 124: d.x = step
        case 125: d.y = -step
        case 126: d.y = step
        default: super.keyDown(with: event); return
        }
        if let r = rect { rect = clamp(r.offsetBy(dx: d.x, dy: d.y)); needsDisplay = true }
    }

    private func commitCurrent() {
        if editing { performToolbarAction("save"); return }
        guard let rect, rect.width >= 8, rect.height >= 8 else { NSSound.beep(); return }
        let global = CGRect(x: unionFrame.minX + rect.minX,
                            y: unionFrame.minY + rect.minY,
                            width: rect.width, height: rect.height)
        controller?.commit(rectGlobal: global)
    }

    private func cyclePreset() {
        let all = CaptureSelectionPreset.allCases
        let i = (all.firstIndex(of: preset) ?? 0) + 1
        preset = all[i % all.count]
        MacShotController.shared.selectionPreset = preset
        needsDisplay = true
    }

    private func constrainedRect(anchor: CGPoint, current: CGPoint) -> CGRect {
        var dx = current.x - anchor.x, dy = current.y - anchor.y
        switch preset {
        case .free:
            break
        case .ratio(_, let ratio):
            if abs(dx) / max(abs(dy), 1) > ratio { dy = (dy < 0 ? -1 : 1) * abs(dx) / ratio }
            else { dx = (dx < 0 ? -1 : 1) * abs(dy) * ratio }
        case .pixels(_, let w, let h):
            let ratio = CGFloat(w) / CGFloat(max(h, 1))
            if abs(dx) / max(abs(dy), 1) > ratio { dy = (dy < 0 ? -1 : 1) * abs(dx) / ratio }
            else { dx = (dx < 0 ? -1 : 1) * abs(dy) * ratio }
        }
        let r = CGRect(x: min(anchor.x, anchor.x + dx), y: min(anchor.y, anchor.y + dy),
                       width: abs(dx), height: abs(dy))
        return clamp(r)
    }

    private func resize(_ r: CGRect, handle: SelectionHandleKind, to p: CGPoint) -> CGRect {
        var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
        switch handle {
        case .tl: minX = p.x; minY = p.y
        case .tm: minY = p.y
        case .tr: maxX = p.x; minY = p.y
        case .ml: minX = p.x
        case .mr: maxX = p.x
        case .bl: minX = p.x; maxY = p.y
        case .bm: maxY = p.y
        case .br: maxX = p.x; maxY = p.y
        case .none: return r
        }
        var out = CGRect(x: min(minX, maxX), y: min(minY, maxY),
                         width: abs(maxX - minX), height: abs(maxY - minY))
        if case .ratio(_, let ratio) = preset { out = fitAspect(out, ratio: ratio, handle: handle) }
        if case .pixels(_, let w, let h) = preset {
            out = fitAspect(out, ratio: CGFloat(w) / CGFloat(max(h, 1)), handle: handle)
        }
        return clamp(out)
    }

    private func fitAspect(_ r: CGRect, ratio: CGFloat, handle: SelectionHandleKind) -> CGRect {
        var w = r.width, h = r.height
        if w / max(h, 1) > ratio { h = w / ratio } else { w = h * ratio }
        switch handle {
        case .tm, .bm: w = h * ratio; return CGRect(x: r.midX - w/2, y: r.minY, width: w, height: h)
        case .ml, .mr: h = w / ratio; return CGRect(x: r.minX, y: r.midY - h/2, width: w, height: h)
        default: break
        }
        return CGRect(x: r.minX, y: r.minY, width: w, height: h)
    }

    private func clamp(_ r: CGRect) -> CGRect {
        var out = r
        out.size.width = min(out.width, bounds.width)
        out.size.height = min(out.height, bounds.height)
        out.origin.x = max(0, min(out.origin.x, bounds.width - out.width))
        out.origin.y = max(0, min(out.origin.y, bounds.height - out.height))
        return out
    }

    private func hitHandle(_ p: CGPoint, rect r: CGRect) -> SelectionHandleKind {
        let pts: [(SelectionHandleKind, CGPoint)] = [
            (.tl, CGPoint(x: r.minX, y: r.minY)), (.tm, CGPoint(x: r.midX, y: r.minY)),
            (.tr, CGPoint(x: r.maxX, y: r.minY)), (.ml, CGPoint(x: r.minX, y: r.midY)),
            (.mr, CGPoint(x: r.maxX, y: r.midY)), (.bl, CGPoint(x: r.minX, y: r.maxY)),
            (.bm, CGPoint(x: r.midX, y: r.maxY)), (.br, CGPoint(x: r.maxX, y: r.maxY))
        ]
        for (k, q) in pts where hypot(p.x-q.x, p.y-q.y) <= 9 { return k }
        return .none
    }

    private func snap(_ p: CGPoint) -> CGPoint {
        var bestX = p.x, bestY = p.y
        var bestXd: CGFloat = 10, bestYd: CGFloat = 10
        for line in snapLines.vertical where abs(line - p.x) < bestXd {
            bestXd = abs(line - p.x); bestX = line
        }
        for line in snapLines.horizontal where abs(line - p.y) < bestYd {
            bestYd = abs(line - p.y); bestY = line
        }
        guard let image = snapshot else { return CGPoint(x: bestX, y: bestY) }
        let sx = CGFloat(image.width) / max(bounds.width, 1)
        let sy = CGFloat(image.height) / max(bounds.height, 1)
        let rep = NSBitmapImageRep(cgImage: image)
        let cx = Int(p.x * sx), cy = Int(p.y * sy)
        let radius = Int(8 * max(sx, 1))
        func color(_ x: Int, _ y: Int) -> NSColor? {
            let px = min(max(x, 0), image.width - 1)
            let py = min(max(y, 0), image.height - 1)
            return rep.colorAt(x: px, y: image.height - 1 - py)
        }
        func diff(_ a: NSColor?, _ b: NSColor?) -> CGFloat {
            guard let a, let b else { return 0 }
            return abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)
        }
        for d in -radius...radius where abs(d) <= Int(8 * max(sx, 1)) {
            if diff(color(cx+d, cy), color(cx+d+1, cy)) > 0.18, CGFloat(abs(d)) < bestXd {
                bestXd = CGFloat(abs(d)); bestX = CGFloat(cx+d)/sx
            }
            if diff(color(cx, cy+d), color(cx, cy+d+1)) > 0.18, CGFloat(abs(d)) < bestYd {
                bestYd = CGFloat(abs(d)); bestY = CGFloat(cy+d)/sy
            }
        }
        return CGPoint(x: bestX, y: bestY)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
        context.fill(bounds)
        guard let rect else { drawHint(); return }
        context.saveGState()
        context.setBlendMode(.clear)
        context.fill(rect)
        context.restoreGState()

        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1.5; border.stroke()

        let pts = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY),
                   CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY),
                   CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: rect.minX, y: rect.maxY),
                   CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        for p in pts {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: CGRect(x: p.x-4, y: p.y-4, width: 8, height: 8),
                         xRadius: 2, yRadius: 2).fill()
        }
        drawSizeLabel(rect)
        if editing { drawToolbar() } else { drawHint() }
    }

    // MARK: - 原地编辑工具栏

    private func updateToolbar() {
        guard let rect else { toolbarButtons = []; return }
        let actions: [(String, String)] = [
            ("保存", "save"), ("复制", "copy"), ("贴图", "pin"), ("OCR", "ocr"), ("取消", "cancel")
        ]
        let btnW: CGFloat = 64, btnH: CGFloat = 30, gap: CGFloat = 8
        let totalW = CGFloat(actions.count) * btnW + CGFloat(actions.count - 1) * gap
        var y = rect.maxY + 10
        if y + btnH > bounds.height - 8 { y = rect.minY - btnH - 10 }
        var x = rect.midX - totalW / 2
        x = max(8, min(x, bounds.width - totalW - 8))
        y = max(8, y)
        toolbarButtons = actions.enumerated().map { i, item in
            (item.0, CGRect(x: x + CGFloat(i) * (btnW + gap), y: y, width: btnW, height: btnH), item.1)
        }
    }

    private func drawToolbar() {
        let panel = toolbarButtons.reduce(CGRect.null) { $0.union($1.rect) }.insetBy(dx: -8, dy: -6)
        NSColor.black.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 10, yRadius: 10).fill()
        for button in toolbarButtons {
            let highlighted = button.action == "save"
            NSColor(calibratedRed: 0.42, green: 0.35, blue: 0.72, alpha: highlighted ? 0.95 : 0.25).setFill()
            NSBezierPath(roundedRect: button.rect, xRadius: 7, yRadius: 7).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = (button.title as NSString).size(withAttributes: attrs)
            (button.title as NSString).draw(
                at: CGPoint(x: button.rect.midX - size.width / 2, y: button.rect.midY - size.height / 2),
                withAttributes: attrs)
        }
    }

    private func currentImage() -> CGImage? {
        guard let rect, let snapshot else { return nil }
        let global = CGRect(x: unionFrame.minX + rect.minX, y: unionFrame.minY + rect.minY,
                            width: rect.width, height: rect.height)
        return snapshot.croppedToGlobalRect(global, union: unionFrame)
    }

    private func performToolbarAction(_ action: String) {
        let image = currentImage()
        switch action {
        case "save":
            if let image { MacShotController.shared.saveEditedImage(image) }
            controller?.cancel()
        case "copy":
            if let image { CaptureExporter.copyToPasteboard(image) }
            MacShotController.shared.showToast("已复制到剪贴板")
            controller?.cancel()
        case "pin":
            if let image { PinWindowController.shared.pin(image) }
            controller?.cancel()
        case "ocr":
            if let image { OCRResultController.shared.recognize(image) }
            controller?.cancel()
        default:
            controller?.cancel()
        }
    }

    private func drawSizeLabel(_ rect: CGRect) {
        let text = editing ? "\(Int(rect.width)) × \(Int(rect.height))" : "\(Int(rect.width)) × \(Int(rect.height))   ⏎ 确认"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let lr = CGRect(x: rect.maxX - size.width - 12,
                        y: max(rect.maxY + 8, 8), width: size.width + 12, height: size.height + 6)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: lr, xRadius: 5, yRadius: 5).fill()
        (text as NSString).draw(at: CGPoint(x: lr.minX+6, y: lr.minY+3), withAttributes: attrs)
    }

    private func drawHint() {
        let text = editing
            ? "拖动选区可移动 · 拖角缩放 · 点击上方按钮保存/复制/贴图/OCR · Esc 取消"
            : "拖动框选 · 松开后可移动/拖角缩放 · \(preset.label) · Enter 确认 · Option 关闭吸附 · Esc 取消"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let r = CGRect(x: (bounds.width-size.width)/2 - 12, y: bounds.height - 68,
                       width: size.width + 24, height: size.height + 12)
        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(at: CGPoint(x: r.minX+12, y: r.minY+6), withAttributes: attrs)
    }
}

private extension CGImage {
    func croppedToGlobalRect(_ rect: CGRect, union: CGRect) -> CGImage? {
        guard union.width > 0, union.height > 0 else { return nil }
        let sx = CGFloat(width) / union.width
        let sy = CGFloat(height) / union.height
        let localX = (rect.minX - union.minX) * sx
        let localY = (union.maxY - rect.maxY) * sy
        let px = CGRect(x: localX, y: localY, width: rect.width * sx, height: rect.height * sy).integral
        guard px.width >= 1, px.height >= 1 else { return nil }
        return cropping(to: px)
    }
}
