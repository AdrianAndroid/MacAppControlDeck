import AppKit
import CoreGraphics

final class AreaSelectionController {
    static let shared = AreaSelectionController()

    private var window: SelectionWindow?
    private var view: SelectionView?
    private var completion: ((NSScreen, CGRect, CGImage?) -> Void)?
    private var recordingCompletion: ((NSScreen, CGRect, RecordingFormat, Int, Bool, Bool) -> Void)?
    private var escapeMonitor: Any?
    private var snapshot: CGImage?
    private var unionFrame: CGRect = .zero

    var isActive: Bool { window != nil }

    func begin(completion: @escaping (NSScreen, CGRect, CGImage?) -> Void) {
        start(recording: false, completion: completion)
    }

    /// 录制模式：覆盖层只显示录制设置（开始/取消/系统声音/麦克风/格式与帧率），
    /// 不显示标注工具；确认后把选区交给调用方开始录制（与 macshot 一致）。
    func beginRecording(initialFormat: RecordingFormat = .mp4,
                        completion: @escaping (NSScreen, CGRect, RecordingFormat, Int, Bool, Bool) -> Void) {
        recordingCompletion = completion
        start(recording: true) { _, _, _ in }
        view?.recordingFormat = initialFormat
    }

    private func start(recording: Bool, completion: @escaping (NSScreen, CGRect, CGImage?) -> Void) {
        guard window == nil else { return }
        self.completion = completion
        let frames = NSScreen.screens.map(\.frame)
        guard !frames.isEmpty else { return }
        unionFrame = frames.reduce(CGRect.null) { $0.union($1) }

        let window = SelectionWindow(contentRect: unionFrame)
        let view = SelectionView(frame: CGRect(origin: .zero, size: unionFrame.size))
        view.controller = self
        view.preset = MacShotController.shared.selectionPreset
        view.isRecordingSetup = recording
        if recording {
            let options = MacShotController.shared.recordingOptions
            view.recordingFormat = .mp4
            view.recordingFPS = options.fps
            view.recordingSystemAudio = options.systemAudio
            view.recordingMic = options.microphone
        }
        window.contentView = view
        // 抓冻结帧期间对自己隐藏，避免把遮罩/工具条截进背景；抓完恢复，便于用户截图。
        window.sharingType = .none
        window.setFrame(unionFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        self.window = window
        self.view = view

        // 先立刻显示遮罩（自身的窗口对截图 API 不可见），再在后台抓取冻结帧：
        // 避免打开选区时因为整屏 Retina 抓图卡住主线程。
        let context = ScreenCaptureManager.makeImmediateCaptureContext()
        DispatchQueue.global(qos: .userInitiated).async {
            let captures = ScreenCaptureManager.captureAllScreensImmediately(context: context)
            let image = ScreenCaptureService.composeStitched(captures: captures)
            DispatchQueue.main.async { [weak self, weak view] in
                self?.window?.sharingType = .readOnly
                guard let view, self?.view === view else { return }
                view.snapshot = image
                view.needsDisplay = true
            }
        }

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

    fileprivate func commitRecording(rectGlobal: CGRect) {
        guard let recordingCompletion, let view else { return }
        let center = CGPoint(x: rectGlobal.midX, y: rectGlobal.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(rectGlobal) })
            ?? NSScreen.main
        guard let screen else { return }
        let (format, fps, sysAudio, mic) = (view.recordingFormat, view.recordingFPS,
                                            view.recordingSystemAudio, view.recordingMic)
        finish()
        recordingCompletion(screen, rectGlobal, format, fps, sysAudio, mic)
    }

    func cancel() { finish() }

    private func finish() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        completion = nil
        recordingCompletion = nil
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
        sharingType = .none
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
    var isRecordingSetup = false
    var recordingFormat: RecordingFormat = .mp4
    var recordingFPS = 30
    var recordingSystemAudio = true
    var recordingMic = false

    private var rect: CGRect?
    private var anchor: CGPoint = .zero
    private var startRect: CGRect = .zero
    private var mode: Mode = .idle
    private var handle: SelectionHandleKind = .none
    private var unionFrame: CGRect = .zero
    private var mainMaxY: CGFloat = 0
    /// 屏幕像素 / 视图点 的比例（Retina 为 2）。
    private var pixelScale: CGFloat {
        guard let snapshot, bounds.width > 0 else { return 1 }
        return CGFloat(snapshot.width) / bounds.width
    }

    private var snapLines: (vertical: [CGFloat], horizontal: [CGFloat]) = ([], [])
    private var windowRects: [CGRect] = []
    private var hoverRect: CGRect?
    private var snapshotRep: NSBitmapImageRep?

    private enum Mode { case idle, creating, moving, resizing }

    // 原地编辑态（不再打开独立编辑窗口）
    private var editing = false
    private var bottomStrip: CaptureToolbarStripView?
    private var rightStrip: CaptureToolbarStripView?
    private var optionsStrip: CaptureToolbarStripView?

    // 标注
    private enum DrawingTool: String {
        case move, rect, ellipse, line, arrow, pen, marker, text, mosaic
        var title: String {
            switch self {
            case .move: return "移动"
            case .rect: return "矩形"
            case .ellipse: return "椭圆"
            case .line: return "直线"
            case .arrow: return "箭头"
            case .pen: return "画笔"
            case .marker: return "荧光笔"
            case .text: return "文字"
            case .mosaic: return "马赛克"
            }
        }
        var symbol: String {
            switch self {
            case .move: return "cursorarrow"
            case .rect: return "rectangle"
            case .ellipse: return "circle"
            case .line: return "line.diagonal"
            case .arrow: return "arrow.up.right"
            case .pen: return "pencil"
            case .marker: return "highlighter"
            case .text: return "textformat"
            case .mosaic: return "square.grid.3x3.fill"
            }
        }
    }
    private struct Annotation {
        var tool: DrawingTool
        var points: [CGPoint]
        var color: NSColor
        var width: CGFloat
        var text: String?
        var lineStyle: LineStyle = .solid
    }

    private let resolutionBox = SelectionResolutionBox()
    private var tool: DrawingTool = .move
    private var inkColor: NSColor = .systemRed
    private var inkWidth: CGFloat = 4
    private var lineStyle: LineStyle = .solid
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
        resolutionBox.onCommit = { [weak self] w, h in self?.applyResolution(width: w, height: h) }
        resolutionBox.isHidden = true
        addSubview(resolutionBox)
    }

    private func buildSnapLines() {
        var vx: [CGFloat] = [0, bounds.width]
        var hy: [CGFloat] = [0, bounds.height]
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            snapLines = (vx, hy); return
        }
        windowRects = []
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
            windowRects.append(CGRect(x: localX, y: localY, width: w, height: h))
        }
        snapLines = (vx, hy)
    }

    override func mouseMoved(with event: NSEvent) {
        guard !editing, mode == .idle else {
            if hoverRect != nil { hoverRect = nil; needsDisplay = true }
            return
        }
        let p = convert(event.locationInWindow, from: nil)
        let hit = windowRects.first(where: { $0.contains(p) })
        if hit != hoverRect {
            hoverRect = hit
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        anchor = p
        if isRecordingSetup {
            if let r = rect, r.insetBy(dx: -2, dy: -2).contains(p) {
                mode = .moving; startRect = r
                return
            }
            mode = .creating
            hoverRect = nil
            rect = CGRect(origin: p, size: .zero)
            needsDisplay = true
            return
        }
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
        hoverRect = nil
        rect = CGRect(origin: p, size: .zero)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        var p = convert(event.locationInWindow, from: nil)
        if let drawingTool, let r = rect {
            p.x = min(max(p.x, r.minX), r.maxX)
            p.y = min(max(p.y, r.minY), r.maxY)
            if drawingTool == .pen {
                currentPoints.append(p)
            } else {
                let first = currentPoints.first ?? p
                let target = event.modifierFlags.contains(.shift)
                    ? constrainedDrawingPoint(from: first, to: p, tool: drawingTool)
                    : p
                currentPoints = [first, target]
            }
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
        if editing { layoutToolbars() }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let drawingTool {
            if currentPoints.count >= 1 {
                let points = drawingTool == .pen ? smoothed(currentPoints) : currentPoints
                annotations.append(Annotation(tool: drawingTool, points: points,
                                              color: inkColor, width: inkWidth, text: nil,
                                              lineStyle: lineStyle))
                redoStack.removeAll()
            }
            self.drawingTool = nil
            currentPoints = []
            needsDisplay = true
            return
        }
        mode = .idle
        if let r = rect, r.width < 8 || r.height < 8 { rect = nil }
        if rect == nil { resolutionBox.isHidden = true }
        if let r = rect, !editing, mode == .idle { editing = true; rebuildToolbars() }
        if let r = rect, case .pixels(_, let w, let h) = preset {
            let scale = pixelScale
            let target = CGRect(x: r.minX, y: r.minY,
                                width: CGFloat(w) / scale, height: CGFloat(h) / scale)
            rect = clamp(target)
        }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { controller?.cancel(); return }
        if isRecordingSetup {
            if event.keyCode == 36 || event.keyCode == 76 { startRecording(); return }
            if event.keyCode == 51 || event.keyCode == 117 { rect = nil; editing = false; hideToolbars(); needsDisplay = true; return }
            return
        }
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
                let order: [DrawingTool] = [.move, .rect, .ellipse, .line, .arrow, .pen, .marker, .text, .mosaic]
                if n >= 1, n <= order.count { tool = order[n - 1]; needsDisplay = true; return }
            }
        }
        if event.keyCode == 36 || event.keyCode == 76 { commitCurrent(); return }
        if event.keyCode == 48 { cyclePreset(); return }
        if event.keyCode == 51 || event.keyCode == 117 {
            rect = nil
            resolutionBox.isHidden = true
            needsDisplay = true
            return
        }
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

    private func constrainedDrawingPoint(from start: CGPoint, to point: CGPoint,
                                         tool: DrawingTool) -> CGPoint {
        var dx = point.x - start.x
        var dy = point.y - start.y
        switch tool {
        case .rect, .ellipse, .mosaic:
            let size = max(abs(dx), abs(dy))
            dx = (dx < 0 ? -1 : 1) * size
            dy = (dy < 0 ? -1 : 1) * size
        case .line, .arrow:
            let angle = atan2(dy, dx)
            let step = CGFloat.pi / 4
            let snapped = (angle / step).rounded() * step
            let length = hypot(dx, dy)
            dx = cos(snapped) * length
            dy = sin(snapped) * length
        default:
            break
        }
        return CGPoint(x: start.x + dx, y: start.y + dy)
    }

    /// 画笔平滑：3 点移动平均 + 一次 Chaikin，贴近上游 PencilToolHandler 的手感。
    private func smoothed(_ raw: [CGPoint]) -> [CGPoint] {
        guard raw.count > 2 else { return raw }
        var moving: [CGPoint] = [raw[0]]
        for i in 1..<(raw.count - 1) {
            let a = raw[i - 1], b = raw[i], c = raw[i + 1]
            moving.append(CGPoint(x: (a.x + b.x * 2 + c.x) / 4, y: (a.y + b.y * 2 + c.y) / 4))
        }
        moving.append(raw[raw.count - 1])
        var out: [CGPoint] = [moving[0]]
        for i in 0..<(moving.count - 1) {
            let p = moving[i], q = moving[i + 1]
            out.append(CGPoint(x: p.x * 0.75 + q.x * 0.25, y: p.y * 0.75 + q.y * 0.25))
            out.append(CGPoint(x: p.x * 0.25 + q.x * 0.75, y: p.y * 0.25 + q.y * 0.75))
        }
        out.append(moving[moving.count - 1])
        return out
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
        if snapshotRep == nil { snapshotRep = NSBitmapImageRep(cgImage: image) }
        guard let rep = snapshotRep else { return CGPoint(x: bestX, y: bestY) }
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
        if let hoverRect, rect == nil {
            NSColor.controlAccentColor.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: hoverRect, xRadius: 4, yRadius: 4).fill()
            NSColor.controlAccentColor.withAlphaComponent(0.9).setStroke()
            let outline = NSBezierPath(roundedRect: hoverRect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            outline.lineWidth = 2
            outline.stroke()
        }
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
        if !editing || mode != .idle { drawThirdsGrid(rect) }
        if editing, let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.clip(to: rect)
            drawAnnotations(ctx: ctx, snapshot: snapshot)
            ctx.restoreGState()
        }
        updateResolutionBox(rect)
        if !editing { drawHint() }
    }

    // MARK: - 原地编辑工具栏（移植 macshot 的 ToolbarStripView / ToolbarButtonView）

    private var toolButtons: [CaptureToolbarButton] {
        let tools: [DrawingTool] = [.move, .rect, .ellipse, .line, .arrow,
                                    .pen, .marker, .text, .mosaic]
        return tools.map { item in
            CaptureToolbarButton(action: .tool(item.rawValue),
                                 sfSymbol: item.symbol,
                                 text: nil,
                                 tooltip: item.title,
                                 isSelected: tool == item)
        }
    }

    private var colorButtons: [CaptureToolbarButton] {
        let swatches: [(NSColor, String)] = [
            (.systemRed, "红"), (.systemYellow, "黄"), (.systemGreen, "绿"),
            (.systemBlue, "蓝"), (.white, "白")
        ]
        var buttons = swatches.map { color, name in
            CaptureToolbarButton(action: .color(color), sfSymbol: nil, text: nil,
                                 tooltip: name, isSelected: false, swatchColor: color)
        }
        buttons.append(CaptureToolbarButton(action: .palette, sfSymbol: "paintpalette.fill",
                                            text: nil, tooltip: "自定颜色"))
        return buttons
    }

    private var widthButtons: [CaptureToolbarButton] {
        [2, 4, 8].map { value in
            CaptureToolbarButton(action: .width(CGFloat(value)), sfSymbol: nil,
                                 text: "\(value)", tooltip: "\(value)px",
                                 isSelected: Int(inkWidth) == value)
        }
    }

    private var styleButtons: [CaptureToolbarButton] {
        LineStyle.allCases.map { style in
            CaptureToolbarButton(action: .lineStyle(style.rawValue), sfSymbol: nil,
                                 text: style == .solid ? "实" : style == .dashed ? "虚" : "点",
                                 tooltip: style.title, isSelected: lineStyle == style)
        }
    }

    private var actionButtons: [CaptureToolbarButton] {
        [
            CaptureToolbarButton(action: .save, sfSymbol: "square.and.arrow.down.fill",
                                 text: nil, tooltip: "保存"),
            CaptureToolbarButton(action: .copy, sfSymbol: "doc.on.doc",
                                 text: nil, tooltip: "复制"),
            CaptureToolbarButton(action: .pin, sfSymbol: "pin.fill",
                                 text: nil, tooltip: "钉图"),
            CaptureToolbarButton(action: .ocr, sfSymbol: "doc.text.viewfinder",
                                 text: nil, tooltip: "OCR"),
            CaptureToolbarButton(action: .cancel, sfSymbol: "xmark",
                                 text: nil, tooltip: "关闭"),
        ]
    }

    private func rebuildToolbars() {
        guard rect != nil else { hideToolbars(); return }
        if isRecordingSetup {
            rebuildRecordingToolbars()
            return
        }
        bottomStrip?.isHidden = false
        optionsStrip?.isHidden = false
        if bottomStrip == nil {
            let strip = CaptureToolbarStripView(orientation: .horizontal)
            strip.onClick = { [weak self] action in self?.handleToolbar(action) }
            addSubview(strip)
            bottomStrip = strip
        }
        if optionsStrip == nil {
            let strip = CaptureToolbarStripView(orientation: .horizontal)
            strip.onClick = { [weak self] action in self?.handleToolbar(action) }
            addSubview(strip)
            optionsStrip = strip
        }
        if rightStrip == nil {
            let strip = CaptureToolbarStripView(orientation: .vertical)
            strip.onClick = { [weak self] action in self?.handleToolbar(action) }
            addSubview(strip)
            rightStrip = strip
        }

        var bottom = toolButtons
        bottom += colorButtons
        bottom.append(CaptureToolbarButton(action: .undo, sfSymbol: "arrow.uturn.backward",
                                           text: nil, tooltip: "撤销"))
        bottom.append(CaptureToolbarButton(action: .redo, sfSymbol: "arrow.uturn.forward",
                                           text: nil, tooltip: "重做"))
        bottomStrip?.setButtons(bottom)
        optionsStrip?.setButtons(widthButtons + styleButtons)
        rightStrip?.setButtons(actionButtons)
        layoutToolbars()
        needsDisplay = true
    }

    private var recordingButtons: [CaptureToolbarButton] {
        [
            CaptureToolbarButton(action: .startRecord, sfSymbol: "record.circle",
                                 text: nil, tooltip: "开始录制",
                                 tintColor: .systemRed),
            CaptureToolbarButton(action: .cancel, sfSymbol: "xmark",
                                 text: nil, tooltip: "取消录制"),
            CaptureToolbarButton(action: .toggleSystemAudio,
                                 sfSymbol: recordingSystemAudio ? "speaker.wave.2.fill" : "speaker.slash",
                                 text: nil, tooltip: "录制系统声音",
                                 isSelected: recordingSystemAudio),
            CaptureToolbarButton(action: .toggleMic,
                                 sfSymbol: recordingMic ? "mic.fill" : "mic.slash",
                                 text: nil, tooltip: "录制麦克风",
                                 isSelected: recordingMic),
            CaptureToolbarButton(action: .recordSettings, sfSymbol: "gearshape",
                                 text: nil, tooltip: "录制格式 / 帧率"),
        ]
    }

    private func rebuildRecordingToolbars() {
        if rightStrip == nil {
            let strip = CaptureToolbarStripView(orientation: .vertical)
            strip.onClick = { [weak self] action in self?.handleToolbar(action) }
            addSubview(strip)
            rightStrip = strip
        }
        bottomStrip?.isHidden = true
        optionsStrip?.isHidden = true
        rightStrip?.isHidden = false
        rightStrip?.setButtons(recordingButtons)
        layoutToolbars()
        needsDisplay = true
    }

    private func startRecording() {
        guard let rect, rect.width >= 8, rect.height >= 8 else { NSSound.beep(); return }
        let global = CGRect(x: unionFrame.minX + rect.minX,
                            y: unionFrame.minY + rect.minY,
                            width: rect.width, height: rect.height)
        controller?.commitRecording(rectGlobal: global)
    }

    private func showRecordingSettingsMenu() {
        let menu = NSMenu()
        let formatItem = NSMenuItem(title: "格式", action: nil, keyEquivalent: "")
        let formatMenu = NSMenu(title: "格式")
        for (title, format) in [("MP4", RecordingFormat.mp4), ("GIF", RecordingFormat.gif)] {
            let item = NSMenuItem(title: title, action: #selector(setRecordingFormat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format == .mp4 ? "mp4" : "gif"
            item.state = recordingFormat == format ? .on : .off
            formatMenu.addItem(item)
        }
        formatItem.submenu = formatMenu
        menu.addItem(formatItem)

        let fpsItem = NSMenuItem(title: "帧率", action: nil, keyEquivalent: "")
        let fpsMenu = NSMenu(title: "帧率")
        for fps in [15, 30, 60, 120] {
            let item = NSMenuItem(title: "\(fps) fps", action: #selector(setRecordingFPS(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = fps
            item.state = recordingFPS == fps ? .on : .off
            fpsMenu.addItem(item)
        }
        fpsItem.submenu = fpsMenu
        menu.addItem(fpsItem)

        let point = convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func setRecordingFormat(_ sender: NSMenuItem) {
        recordingFormat = (sender.representedObject as? String) == "gif" ? .gif : .mp4
        rebuildToolbars()
    }

    @objc private func setRecordingFPS(_ sender: NSMenuItem) {
        recordingFPS = sender.representedObject as? Int ?? 30
        rebuildToolbars()
    }

    private func hideToolbars() {
        bottomStrip?.isHidden = true
        optionsStrip?.isHidden = true
        rightStrip?.isHidden = true
    }

    /// 位置算法移植自 macshot OverlayView.repositionToolbars()：
    /// 横向工具条默认在选区下方（居中），竖向动作条贴在选区右侧并与选区顶对齐。
    private func layoutToolbars() {
        guard let rect, let rightStrip else { return }
        let visible = editing
        rightStrip.isHidden = !visible
        guard visible else { return }

        guard !isRecordingSetup else {
            bottomStrip?.isHidden = true
            optionsStrip?.isHidden = true
            let size = rightStrip.frame.size
            var rx = rect.maxX + 6
            if rx + size.width > bounds.maxX - 4 { rx = rect.minX - size.width - 6 }
            rx = max(bounds.minX + 4, min(rx, bounds.maxX - size.width - 4))
            var ry = rect.maxY - size.height
            ry = max(bounds.minY + 4, min(ry, bounds.maxY - size.height - 4))
            rightStrip.frame.origin = NSPoint(x: rx, y: ry)
            return
        }

        guard let bottomStrip, let optionsStrip else { return }
        bottomStrip.isHidden = false
        optionsStrip.isHidden = false

        let rightSize = rightStrip.frame.size
        let bottomSize = bottomStrip.frame.size
        let optionsSize = optionsStrip.frame.size
        let optRowH: CGFloat = 38

        let rightMargin: CGFloat = 50
        let rightFitsRight = rect.maxX < bounds.maxX - rightMargin
        let rightFitsLeft = rect.minX > bounds.minX + rightMargin
        let selectionTooNarrow = !rightFitsRight && !rightFitsLeft
            && rect.width < bounds.width * 0.5

        var rx: CGFloat
        var ry: CGFloat
        if selectionTooNarrow {
            rx = rect.maxX - rightSize.width
            rx = max(bounds.minX + 4, min(rx, bounds.maxX - rightSize.width - 4))
            ry = rect.minY - rightSize.height - 6
            ry = max(bounds.minY + 4, min(ry, bounds.maxY - rightSize.height - 4))
        } else {
            if rightFitsRight {
                rx = rect.maxX + 6
            } else if rightFitsLeft {
                rx = rect.minX - rightSize.width - 6
            } else {
                rx = rect.maxX - rightSize.width - 6
            }
            rx = max(bounds.minX + 4, min(rx, bounds.maxX - rightSize.width - 4))
            ry = rect.maxY - rightSize.height
            ry = max(bounds.minY + 4, min(ry, bounds.maxY - rightSize.height - 4))
        }

        let belowY = rect.minY - bottomSize.height - 6
        let belowFits = (belowY - optRowH) >= bounds.minY + 4
        let aboveY = rect.maxY + optRowH + 6
        let aboveFits = (aboveY + bottomSize.height) <= bounds.maxY - 4

        var by: CGFloat
        if belowFits {
            by = belowY
        } else if aboveFits {
            by = aboveY
        } else {
            by = rect.minY + optRowH + 6
            by = max(bounds.minY + optRowH + 4, min(by, bounds.maxY - bottomSize.height - 4))
        }

        var bx = rect.midX - bottomSize.width / 2
        bx = max(bounds.minX + 4, min(bx, bounds.maxX - bottomSize.width - 4))

        // 横向工具条与竖向动作条冲突时，把动作条横向推开（与上游一致）。
        let bottomMinY = by - optRowH
        let bottomMaxY = by + bottomSize.height
        if bottomMaxY > ry && bottomMinY < ry + rightSize.height {
            if bx + bottomSize.width <= rx - 4 || bx >= rx + rightSize.width + 4 {
                // 不重叠
            } else {
                let pushRight = bx + bottomSize.width + 4
                let pushLeft = bx - rightSize.width - 4
                if pushRight + rightSize.width <= bounds.maxX - 4 {
                    rx = pushRight
                } else if pushLeft >= bounds.minX + 4 {
                    rx = pushLeft
                } else if by - optRowH - rightSize.height - 4 >= bounds.minY + 4 {
                    ry = by - optRowH - rightSize.height - 4
                }
            }
        }

        bottomStrip.frame.origin = NSPoint(x: bx, y: by)
        rightStrip.frame.origin = NSPoint(x: rx, y: ry)
        var ox = rect.midX - optionsSize.width / 2
        ox = max(bounds.minX + 4, min(ox, bounds.maxX - optionsSize.width - 4))
        // 与上游一致：选项行在工具条下方（覆盖层模式），而不是塞进选区内。
        optionsStrip.frame.origin = NSPoint(x: ox, y: by - optionsSize.height - 2)
    }

    private func handleToolbar(_ action: CaptureToolbarAction) {
        switch action {
        case .tool(let raw):
            tool = DrawingTool(rawValue: raw) ?? .move
        case .color(let color):
            inkColor = color
        case .palette:
            let panel = NSColorPanel.shared
            panel.setTarget(self)
            panel.setAction(#selector(customColorChanged(_:)))
            panel.isContinuous = true
            panel.color = inkColor
            panel.orderFront(nil)
        case .width(let width):
            inkWidth = width
        case .lineStyle(let raw):
            lineStyle = LineStyle(rawValue: raw) ?? .solid
        case .undo:
            if let last = annotations.popLast() { redoStack.append(last) }
        case .redo:
            if let last = redoStack.popLast() { annotations.append(last) }
        case .save:
            performToolbarAction("save")
            return
        case .copy:
            performToolbarAction("copy")
            return
        case .pin:
            performToolbarAction("pin")
            return
        case .ocr:
            performToolbarAction("ocr")
            return
        case .cancel:
            performToolbarAction("cancel")
            return
        case .startRecord:
            startRecording()
            return
        case .toggleSystemAudio:
            recordingSystemAudio.toggle()
        case .toggleMic:
            recordingMic.toggle()
        case .recordSettings:
            showRecordingSettingsMenu()
            return
        }
        needsDisplay = true
        rebuildToolbars()
    }

    @objc private func customColorChanged(_ sender: NSColorPanel) {
        inkColor = sender.color
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
    /// 使用显式像素尺寸的 bitmap context，避免 Retina 下 lockFocus 把图片再放大一倍。
    private func composite(base: CGImage, rect: CGRect) -> CGImage? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: base.width,
                                         pixelsHigh: base.height,
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .calibratedRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else { return base }
        NSGraphicsContext.saveGraphicsState()
        guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return base
        }
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high
        let pixelSize = NSSize(width: base.width, height: base.height)
        NSImage(cgImage: base, size: pixelSize).draw(in: NSRect(origin: .zero, size: pixelSize))
        let ctx = graphics.cgContext
        let scale = CGFloat(base.width) / max(rect.width, 1)
        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -rect.minX, y: -rect.minY)
        drawAnnotations(ctx: ctx, snapshot: nil)
        ctx.restoreGState()
        NSGraphicsContext.restoreGraphicsState()
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
        if let pattern = annotation.lineStyle.pattern {
            let dashed = pattern.map { $0 * max(annotation.width, 1) }
            ctx.setLineDash(phase: 0, lengths: dashed)
        }
        switch annotation.tool {
        case .rect:
            guard let last = annotation.points.last else { break }
            let r = CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y)
            ctx.stroke(r.standardized)
        case .ellipse:
            guard let last = annotation.points.last else { break }
            let r = CGRect(x: first.x, y: first.y, width: last.x - first.x, height: last.y - first.y).standardized
            ctx.strokeEllipse(in: r)
        case .line:
            guard let last = annotation.points.last else { break }
            ctx.move(to: first); ctx.addLine(to: last); ctx.strokePath()
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
        case .pen, .marker:
            guard annotation.points.count > 1 else { break }
            if annotation.tool == .marker {
                ctx.setAlpha(0.35)
                ctx.setLineWidth(annotation.width * 2.5)
            }
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

    private func drawThirdsGrid(_ rect: CGRect) {
        let path = NSBezierPath()
        for i in 1...2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 3
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
        }
        path.lineWidth = 1
        NSColor.white.withAlphaComponent(0.45).setStroke()
        path.stroke()
    }

    private func updateResolutionBox(_ rect: CGRect) {
        resolutionBox.isHidden = mode != .idle || rect.width < 8 || rect.height < 8
        guard !resolutionBox.isHidden else { return }
        let size = resolutionBox.preferredSize
        var x = rect.minX
        x = min(max(8, x), bounds.width - size.width - 8)
        let below = rect.minY - size.height - 8
        let y = below >= 8 ? below : min(rect.maxY + 8, bounds.height - size.height - 8)
        resolutionBox.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        let scale = pixelScale
        resolutionBox.setDimensions(width: Int((rect.width * scale).rounded()),
                                    height: Int((rect.height * scale).rounded()))
    }

    private func applyResolution(width: Int, height: Int) {
        guard let current = rect else { return }
        let scale = pixelScale
        let target = CGRect(x: current.minX, y: current.maxY - CGFloat(height) / scale,
                            width: CGFloat(width) / scale, height: CGFloat(height) / scale)
        rect = clamp(target)
        needsDisplay = true
    }

    private func drawHint() {
        let text = "拖拽选择区域 · Enter 确认 · Esc 取消 · Tab 切换比例 · Option 关闭吸附"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let panelW = size.width + 28
        let panelH = size.height + 14
        let r = CGRect(x: bounds.midX - panelW / 2,
                       y: bounds.midY - panelH / 2,
                       width: panelW, height: panelH)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(at: CGPoint(x: r.minX + 14, y: r.minY + 7),
                                withAttributes: attrs)
    }
}

/// 选区尺寸输入框：两个可直接编辑的宽/高数字框（上游 ResolutionBoxView 的轻量版）。
private final class SelectionResolutionBox: NSView, NSTextFieldDelegate {
    var onCommit: ((Int, Int) -> Void)?

    private let widthField = NSTextField()
    private let heightField = NSTextField()
    private let timesLabel = NSTextField(labelWithString: "×")
    private var suppressCommit = false

    var preferredSize: CGSize { CGSize(width: 146, height: 26) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor

        configure(widthField)
        configure(heightField)
        timesLabel.font = .systemFont(ofSize: 12)
        timesLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        timesLabel.alignment = .center
        addSubview(widthField)
        addSubview(timesLabel)
        addSubview(heightField)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure(_ field: NSTextField) {
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        field.alignment = .center
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.white.withAlphaComponent(0.14)
        field.textColor = .white
        field.focusRingType = .none
        field.delegate = self
        field.wantsLayer = true
        field.layer?.cornerRadius = 5
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 100000
        formatter.allowsFloats = false
        field.formatter = formatter
    }

    override func layout() {
        super.layout()
        let fieldW: CGFloat = 54, gap: CGFloat = 6, pad: CGFloat = 7
        let h: CGFloat = 20
        let y = (bounds.height - h) / 2
        widthField.frame = CGRect(x: pad, y: y, width: fieldW, height: h)
        timesLabel.frame = CGRect(x: widthField.frame.maxX, y: y - 2, width: gap * 2, height: h + 4)
        heightField.frame = CGRect(x: timesLabel.frame.maxX, y: y, width: fieldW, height: h)
    }

    func setDimensions(width: Int, height: Int) {
        if widthField.currentEditor() == nil { widthField.stringValue = "\(width)" }
        if heightField.currentEditor() == nil { heightField.stringValue = "\(height)" }
    }

    private func commit() {
        guard let w = Int(widthField.stringValue), let h = Int(heightField.stringValue),
              w > 0, h > 0 else { return }
        onCommit?(w, h)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        suppressCommit = true
        commit()
        window?.makeFirstResponder(superview)
        return true
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !suppressCommit else {
            suppressCommit = false
            return
        }
        commit()
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
