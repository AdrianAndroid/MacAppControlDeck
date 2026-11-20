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

private final class SelectionView: NSView, NSTextFieldDelegate {
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

    // 标注
    private enum DrawingTool: String { case move, rect, ellipse, arrow, pen, text, mosaic }
    private struct Annotation {
        var tool: DrawingTool
        var points: [CGPoint]
        var color: NSColor
        var width: CGFloat
        var text: String?
    }
    private var tool: DrawingTool = .move
    private var inkColor: NSColor = .systemRed
    private var inkWidth: CGFloat = 4
    private var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private var currentPoints: [CGPoint] = []
    private var drawingTool: DrawingTool?
    private var textField: NSTextField?

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
            handleToolbarAction(hit.action)
            return
        }
        anchor = p
        if editing, let r = rect, r.contains(p), tool != .move {
            if tool == .text { beginTextInput(at: p); return }
            drawingTool = tool
            currentPoints = [p]
            needsDisplay = true
            return
        }
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
        if let drawingTool, let r = rect {
            p.x = min(max(p.x, r.minX), r.maxX)
            p.y = min(max(p.y, r.minY), r.maxY)
            if drawingTool == .pen { currentPoints.append(p) } else { currentPoints = [currentPoints.first ?? p, p] }
            needsDisplay = true
            return
        }
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
        if let drawingTool {
            if currentPoints.count >= 1 {
                annotations.append(Annotation(tool: drawingTool, points: currentPoints,
                                              color: inkColor, width: inkWidth, text: nil))
                redoStack.removeAll()
            }
            self.drawingTool = nil
            currentPoints = []
            needsDisplay = true
            return
        }
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
        if editing {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "z" {
                if mods.contains(.shift) {
                    if let last = redoStack.popLast() { annotations.append(last) }
                } else if let last = annotations.popLast() {
                    redoStack.append(last)
                }
                needsDisplay = true
                return
            }
            if let chars = event.charactersIgnoringModifiers, let n = Int(chars) {
                let order: [DrawingTool] = [.move, .rect, .ellipse, .arrow, .pen, .text, .mosaic]
                if n >= 1, n <= order.count { tool = order[n - 1]; needsDisplay = true; return }
            }
        }
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
        if editing, let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.clip(to: rect)
            drawAnnotations(ctx: ctx, snapshot: snapshot)
            ctx.restoreGState()
        }
        drawSizeLabel(rect)
        if editing { drawToolbar() } else { drawHint() }
    }

    // MARK: - 原地编辑工具栏

    private func updateToolbar() {
        guard let rect else { toolbarButtons = []; return }
        var buttons: [(String, CGRect, String)] = []

        // 顶部工具条
        let tools: [(String, String, String)] = [
            ("移动", "tool:move", "move"), ("矩形", "tool:rect", "rect"),
            ("椭圆", "tool:ellipse", "ellipse"), ("箭头", "tool:arrow", "arrow"),
            ("画笔", "tool:pen", "pen"), ("文字", "tool:text", "text"),
            ("马赛克", "tool:mosaic", "mosaic")
        ]
        let colors: [(String, String)] = [
            ("红", "color:red"), ("黄", "color:yellow"), ("绿", "color:green"),
            ("蓝", "color:blue"), ("白", "color:white")
        ]
        let widths: [(String, String)] = [("2px", "width:2"), ("4px", "width:4"), ("8px", "width:8")]

        let btnH: CGFloat = 28, gap: CGFloat = 6
        var rowWidth: CGFloat = 0
        var widthsOf: [String: CGFloat] = [:]
        func textWidth(_ t: String) -> CGFloat {
            (t as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width + 18
        }
        for item in tools { let w = textWidth(item.0); widthsOf[item.1] = w; rowWidth += w + gap }
        rowWidth += 10
        for item in ["undo", "redo"] { let w = textWidth("↶"); widthsOf[item] = w; rowWidth += w + gap }
        rowWidth += 12
        for item in colors { let w: CGFloat = 22; widthsOf[item.1] = w; rowWidth += w + gap }
        rowWidth += 10
        for item in widths { let w = textWidth(item.0); widthsOf[item.1] = w; rowWidth += w + gap }

        // 顶部工具条：锚定屏幕顶部、水平居中（与 MacShot 一致，不随选区移动）
        var x = bounds.midX - rowWidth / 2
        x = max(8, min(x, bounds.width - rowWidth - 8))
        let y = bounds.height - btnH - 14

        func add(_ title: String, _ action: String, _ w: CGFloat) {
            buttons.append((title, CGRect(x: x, y: y, width: w, height: btnH), action))
            x += w + gap
        }
        for item in tools { add(item.0, item.1, widthsOf[item.1] ?? 40) }
        add("↶", "undo", widthsOf["undo"] ?? 26)
        add("↷", "redo", widthsOf["redo"] ?? 26)
        for item in colors { add("●", item.1, 22) }
        for item in widths { add(item.0, item.1, widthsOf[item.1] ?? 36) }

        // 右侧竖排动作栏
        let actions: [(String, String)] = [
            ("保存", "save"), ("复制", "copy"), ("贴图", "pin"), ("OCR", "ocr"), ("关闭", "cancel")
        ]
        // 右侧动作栏：锚定屏幕右缘、垂直居中
        let railW: CGFloat = 56
        let railHeight = CGFloat(actions.count) * (btnH + gap) - gap
        var ry = bounds.midY + railHeight / 2 - btnH
        let rx = bounds.width - railW - 12
        for item in actions {
            buttons.append((item.0, CGRect(x: rx, y: ry, width: railW, height: btnH), item.1))
            ry += btnH + gap
        }
        toolbarButtons = buttons
    }

    private func drawToolbar() {
        guard let rect else { return }
        // 顶部面板
        let top = toolbarButtons.filter { $0.rect.midY > rect.midY }.reduce(CGRect.null) { $0.union($1.rect) }
        if !top.isNull {
            NSColor.black.withAlphaComponent(0.78).setFill()
            NSBezierPath(roundedRect: top.insetBy(dx: -10, dy: -6), xRadius: 10, yRadius: 10).fill()
        }
        let rail = toolbarButtons.filter { $0.rect.midY <= rect.midY }.reduce(CGRect.null) { $0.union($1.rect) }
        if !rail.isNull {
            NSColor.black.withAlphaComponent(0.78).setFill()
            NSBezierPath(roundedRect: rail.insetBy(dx: -6, dy: -6), xRadius: 10, yRadius: 10).fill()
        }
        for button in toolbarButtons {
            var active = false
            if button.action.hasPrefix("tool:") {
                active = button.action == "tool:" + tool.rawValue
            } else if button.action.hasPrefix("color:") {
                active = (button.action == colorAction(for: inkColor))
            } else if button.action.hasPrefix("width:") {
                active = button.action == "width:" + String(Int(inkWidth))
            }
            let bg: NSColor = active
                ? NSColor(calibratedRed: 0.42, green: 0.35, blue: 0.75, alpha: 0.95)
                : NSColor.white.withAlphaComponent(0.10)
            bg.setFill()
            NSBezierPath(roundedRect: button.rect, xRadius: 7, yRadius: 7).fill()
            if button.action.hasPrefix("color:") {
                let color = color(forAction: button.action)
                color.setFill()
                NSBezierPath(ovalIn: button.rect.insetBy(dx: 4, dy: 4)).fill()
            } else {
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
    }

    private func colorAction(for color: NSColor) -> String {
        ["color:red", "color:yellow", "color:green", "color:blue", "color:white"]
            .first { nsColor(forAction: $0).usingColorSpace(.sRGB)?.description == color.usingColorSpace(.sRGB)?.description }
            ?? "color:red"
    }

    private func nsColor(forAction action: String) -> NSColor {
        switch action {
        case "color:yellow": return .systemYellow
        case "color:green": return .systemGreen
        case "color:blue": return .systemBlue
        case "color:white": return .white
        default: return .systemRed
        }
    }

    private func color(forAction action: String) -> NSColor { nsColor(forAction: action) }

    private func handleToolbarAction(_ action: String) {
        if action.hasPrefix("tool:") {
            tool = DrawingTool(rawValue: String(action.dropFirst(5))) ?? .move
            needsDisplay = true
            return
        }
        if action.hasPrefix("color:") {
            inkColor = nsColor(forAction: action)
            needsDisplay = true
            return
        }
        if action.hasPrefix("width:") {
            inkWidth = CGFloat(Double(action.dropFirst(6)) ?? 4)
            needsDisplay = true
            return
        }
        switch action {
        case "undo":
            if let last = annotations.popLast() { redoStack.append(last) }
        case "redo":
            if let last = redoStack.popLast() { annotations.append(last) }
        default:
            performToolbarAction(action)
        }
        needsDisplay = true
    }

    private func currentImage() -> CGImage? {
        guard let rect, let base = baseImage() else { return nil }
        return composite(base: base, rect: rect) ?? base
    }

    private func baseImage() -> CGImage? {
        guard let rect, let snapshot else { return nil }
        let global = CGRect(x: unionFrame.minX + rect.minX, y: unionFrame.minY + rect.minY,
                            width: rect.width, height: rect.height)
        return snapshot.croppedToGlobalRect(global, union: unionFrame)
    }

    /// 把标注烘焙进图像；`rect` 为选区（view 坐标），返回像素图。
    private func composite(base: CGImage, rect: CGRect) -> CGImage? {
        let scale = CGFloat(base.width) / max(rect.width, 1)
        let pixelSize = NSSize(width: base.width, height: base.height)
        let image = NSImage(size: pixelSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: base, size: pixelSize).draw(in: NSRect(origin: .zero, size: pixelSize))
        guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return base }
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        drawAnnotations(ctx: ctx, snapshot: nil)
        ctx.restoreGState()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return base }
        return rep.cgImage
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
            if let image, let rect {
                let frame = CGRect(x: unionFrame.minX + rect.minX,
                                   y: unionFrame.minY + rect.minY,
                                   width: rect.width, height: rect.height)
                PinWindowController.shared.pin(image, at: frame)
            }
            controller?.cancel()
        case "ocr":
            if let image { OCRResultController.shared.recognize(image) }
            controller?.cancel()
        default:
            controller?.cancel()
        }
    }

    // MARK: - 标注绘制与导出

    private func drawAnnotations(ctx: CGContext, snapshot: CGImage?) {
        for annotation in annotations { draw(annotation, ctx: ctx, snapshot: snapshot) }
        if let drawingTool, !currentPoints.isEmpty {
            draw(Annotation(tool: drawingTool, points: currentPoints,
                            color: inkColor, width: inkWidth, text: nil),
                 ctx: ctx, snapshot: snapshot)
        }
    }

    private func draw(_ annotation: Annotation, ctx: CGContext, snapshot: CGImage?) {
        guard let first = annotation.points.first else { return }
        ctx.saveGState()
        ctx.setStrokeColor(annotation.color.cgColor)
        ctx.setFillColor(annotation.color.cgColor)
        ctx.setLineWidth(annotation.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        switch annotation.tool {
        case .rect:
            guard let last = annotation.points.last else { break }
            let r = CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y)
            ctx.stroke(r.standardized)
        case .ellipse:
            guard let last = annotation.points.last else { break }
            let r = CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y).standardized
            ctx.strokeEllipse(in: r)
        case .arrow:
            guard let last = annotation.points.last else { break }
            ctx.move(to: first); ctx.addLine(to: last); ctx.strokePath()
            let angle = atan2(last.y - first.y, last.x - first.x)
            let len = max(10, annotation.width * 3)
            for delta in [CGFloat.pi * 0.82, -CGFloat.pi * 0.82] {
                let p = CGPoint(x: last.x + cos(angle + delta) * len, y: last.y + sin(angle + delta) * len)
                ctx.move(to: last); ctx.addLine(to: p)
            }
            ctx.strokePath()
        case .pen:
            guard annotation.points.count > 1 else { break }
            ctx.move(to: first)
            for p in annotation.points.dropFirst() { ctx.addLine(to: p) }
            ctx.strokePath()
        case .text:
            if let text = annotation.text, let snapshot {
                // 导出/预览都走 AppKit 文本绘制更稳妥
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: annotation.color
                ]
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                (text as NSString).draw(at: first, withAttributes: attrs)
                NSGraphicsContext.restoreGraphicsState()
            }
        case .mosaic:
            if let last = annotation.points.last {
                let r = CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y).standardized
                drawMosaic(in: r, ctx: ctx, snapshot: snapshot)
            }
        case .move:
            break
        }
        ctx.restoreGState()
    }

    private func drawMosaic(in rect: CGRect, ctx: CGContext, snapshot: CGImage?) {
        guard let snapshot, let rep = Optional(NSBitmapImageRep(cgImage: snapshot)),
              let sel = self.rect else { return }
        let sx = CGFloat(snapshot.width) / max(bounds.width, 1)
        let sy = CGFloat(snapshot.height) / max(bounds.height, 1)
        let block: CGFloat = 10
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let px = Int((x + block / 2) * sx)
                let py = Int((y + block / 2) * sy)
                let color = rep.colorAt(x: min(px, snapshot.width - 1),
                                        y: snapshot.height - 1 - min(py, snapshot.height - 1)) ?? .black
                color.setFill()
                let r = CGRect(x: x, y: y, width: min(block, rect.maxX - x),
                               height: min(block, rect.maxY - y))
                ctx.setFillColor(color.cgColor)
                ctx.fill(r)
                x += block
            }
            y += block
        }
        _ = sel
    }

    // MARK: - 文本输入

    private func beginTextInput(at point: CGPoint) {
        if let textField { textField.removeFromSuperview(); self.textField = nil }
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: 220, height: 26))
        field.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        field.textColor = inkColor
        field.backgroundColor = NSColor.black.withAlphaComponent(0.35)
        field.isBordered = false
        field.focusRingType = .none
        field.placeholderString = "输入文字，回车确认"
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)
        textField = field
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = textField else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let p = CGPoint(x: field.frame.minX, y: field.frame.midY - 8)
            annotations.append(Annotation(tool: .text, points: [p], color: inkColor,
                                          width: inkWidth, text: text))
            redoStack.removeAll()
        }
        field.removeFromSuperview()
        textField = nil
        needsDisplay = true
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
