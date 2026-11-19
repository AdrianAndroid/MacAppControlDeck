import AppKit
import SwiftUI

/// MacShot chrome metrics, copied from the upstream sources:
/// ToolbarLayout.defaultBgColor / accentColor, ToolbarButtonView.size = 32,
/// ToolbarStripView padding 4 + spacing 2 + radius 6, EditorTopBarView height 32,
/// ToolOptionsRowView height 34, editor content insets 40/40/84/50.
private enum ShotUI {
    static let bg = Color(white: 0.12)
    static let canvas = Color(white: 0.15)
    static let icon = Color.white
    static let accent = Color(.sRGB, red: 0.55, green: 0.30, blue: 0.85, opacity: 1)
    static let radius: CGFloat = 6
    static let button: CGFloat = 32
    static let buttonSpacing: CGFloat = 2
    static let stripPadding: CGFloat = 4
    static let topBarHeight: CGFloat = 32
    static let optionsHeight: CGFloat = 34
}

struct CaptureEditorView: View {
    @ObservedObject var model: CaptureEditorModel
    let onSave: (CGImage) -> Void
    let onCopy: (CGImage) -> Void
    let onPin: (CGImage) -> Void
    let onOCR: (CGImage) -> Void
    let onClose: () -> Void

    @State private var pendingTextPoint: CGPoint?
    @State private var textValue = ""
    @State private var showingText = false

    private var bottomTools: [CaptureTool] {
        [.pen, .line, .arrow, .rectangle, .ellipse, .marker,
         .text, .number, .pixelate, .blur, .highlight, .measure, .crop]
    }

    /// 13 tools + color + undo + redo, same arithmetic as ToolbarStripView.layoutButtons().
    private var bottomStripWidth: CGFloat {
        let count = CGFloat(bottomTools.count + 3)
        return count * ShotUI.button
            + max(0, count - 1) * ShotUI.buttonSpacing
            + ShotUI.stripPadding * 2
    }

    private var showsOptionsRow: Bool {
        switch model.tool {
        case .pen, .marker, .line, .arrow, .rectangle, .filledRectangle,
             .ellipse, .text, .number, .measure, .crop:
            return true
        case .pixelate, .blur, .highlight:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            canvasArea
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                rightStrip
                    .padding(.top, 36)
                    .padding(.trailing, 20)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomDock
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
        .background(ShotUI.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .frame(minWidth: 800, minHeight: 400)
        .sheet(isPresented: $showingText) {
            VStack(alignment: .leading, spacing: 12) {
                Text("添加文字").font(.headline)
                TextField("输入文字", text: $textValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                    .onSubmit { commitText() }
                HStack {
                    Spacer()
                    Button("取消") { showingText = false }
                    Button("添加") { commitText() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Top bar (EditorTopBarView, 32pt)

    private var topBar: some View {
        HStack(spacing: 0) {
            Text("\(Int(model.imageWidth)) × \(Int(model.imageHeight))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.leading, 12)

            ChromeButton(symbol: "crop", title: "裁剪", size: 24, iconSize: 13, radius: 5) {
                model.tool = model.tool == .crop ? .rectangle : .crop
                if model.tool != .crop { model.cropRect = nil }
            }
            .padding(.leading, 16)

            ChromeButton(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                         title: "水平翻转", size: 24, iconSize: 13, radius: 5) {
                model.flipHorizontally()
            }
            .padding(.leading, 4)

            ChromeButton(symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                         title: "垂直翻转", size: 24, iconSize: 13, radius: 5) {
                model.flipVertically()
            }
            .padding(.leading, 4)

            Spacer(minLength: 8)

            dragHandle
                .padding(.trailing, 10)

            ChromeButton(symbol: "xmark", title: "关闭", size: 24, iconSize: 12, radius: 5,
                         action: onClose)
                .padding(.trailing, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ShotUI.topBarHeight)
        .background(ShotUI.bg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(white: 0.25))
                .frame(height: 0.5)
        }
    }

    private var dragHandle: some View {
        ZStack {
            HStack(spacing: 4) {
                GripDots()
                Image(systemName: "photo")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                GripDots()
            }
            WindowDragHandle()
        }
        .frame(width: 40, height: 22)
        .help("拖动标题区域移动窗口")
    }

    // MARK: - Right strip (right toolbar, 32pt buttons)

    private var rightStrip: some View {
        VStack(spacing: ShotUI.buttonSpacing) {
            ChromeButton(symbol: "doc.on.doc", title: "复制") {
                if let image = model.render() { onCopy(image) }
            }
            ChromeButton(symbol: "square.and.arrow.down.fill", title: "保存") {
                if let image = model.render() { onSave(image) }
            }
            ChromeButton(symbol: "pin.fill", title: "钉图") {
                if let image = model.render() { onPin(image) }
            }
            ChromeButton(symbol: "doc.text.viewfinder", title: "OCR") {
                if let image = model.render() { onOCR(image) }
            }
            ChromeButton(symbol: "xmark", title: "关闭", action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(ShotUI.stripPadding)
        .background(
            RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                .fill(ShotUI.bg)
        )
    }

    // MARK: - Bottom dock (options row + bottom toolbar)

    private var bottomDock: some View {
        VStack(spacing: 2) {
            if showsOptionsRow {
                optionsRow
                    .frame(width: bottomStripWidth, height: ShotUI.optionsHeight)
            }
            HStack(spacing: ShotUI.buttonSpacing) {
                ForEach(bottomTools) { tool in
                    EditorToolButton(tool: tool, selected: model.tool == tool) {
                        model.tool = tool
                        if tool != .crop { model.cropRect = nil }
                    }
                }

                colorSwatch

                ChromeButton(symbol: "arrow.uturn.backward", title: "撤销",
                             disabled: !model.canUndo) {
                    model.undo()
                }
                ChromeButton(symbol: "arrow.uturn.forward", title: "重做",
                             disabled: !model.canRedo) {
                    model.redo()
                }
            }
            .padding(ShotUI.stripPadding)
            .background(
                RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                    .fill(ShotUI.bg)
            )
        }
    }

    private var optionsRow: some View {
        HStack(spacing: 4) {
            if model.tool == .crop {
                Text("裁剪区域")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                Spacer(minLength: 8)
                Button {
                    model.applyCrop()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.cropRect == nil ? ShotUI.accent.opacity(0.35) : ShotUI.accent)
                .disabled(model.cropRect == nil)
                .help("应用裁剪")

                Button {
                    model.resetCrop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white.opacity(0.85))
                .disabled(model.cropRect == nil)
                .help("取消裁剪")
            } else {
                Text(model.tool == .text ? "字号" : "粗细")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))

                Slider(value: $model.lineWidth, in: 1...30)
                    .frame(width: 100)
                    .controlSize(.small)
                    .tint(ShotUI.accent)

                Text("\(Int(model.lineWidth))px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .frame(width: 28, alignment: .trailing)

                Spacer(minLength: 8)
            }
        }
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                .fill(ShotUI.bg)
        )
    }

    private var colorSwatch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(model.color)
                .padding(6)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                .padding(6)
            ColorPicker("", selection: $model.color, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02)
        }
        .frame(width: ShotUI.button, height: ShotUI.button)
        .contentShape(Rectangle())
        .help("颜色")
    }

    // MARK: - Canvas

    private var canvasArea: some View {
        GeometryReader { proxy in
            ZStack {
                ShotUI.canvas
                imageAndCanvas(size: proxy.size)
            }
            .clipped()
        }
    }

    private func imageAndCanvas(size: CGSize) -> some View {
        // DetachedEditorWindowController uses contentInsets bottom 84 / right 50
        // plus OverlayView.editorDocumentMargin = 40 around the image.
        let container = CGRect(x: 40, y: 40,
                               width: max(size.width - 40 - 60, 1),
                               height: max(size.height - 40 - 84, 1))
        let fit = fitRect(imageSize: CGSize(width: model.imageWidth, height: model.imageHeight),
                          in: container)
        return ZStack(alignment: .topLeading) {
            Image(nsImage: NSImage(cgImage: model.baseImage,
                                   size: NSSize(width: model.imageWidth, height: model.imageHeight)))
                .resizable()
                .interpolation(.high)
                .frame(width: fit.width, height: fit.height)
                .position(x: fit.midX, y: fit.midY)

            Canvas { context, _ in
                drawAnnotations(context: &context, fit: fit)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .gesture(drawingGesture(fit: fit))
        }
    }

    private func drawingGesture(fit: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let point = imagePoint(from: value.startLocation, fit: fit)
                if model.draft == nil && model.tool != .crop {
                    model.beginDraft(at: point)
                }
                let current = imagePoint(from: value.location, fit: fit)
                model.updateDraft(to: current)
            }
            .onEnded { value in
                let point = imagePoint(from: value.location, fit: fit)
                if model.tool == .text {
                    pendingTextPoint = point
                    textValue = ""
                    showingText = true
                    model.draft = nil
                } else {
                    model.commitDraft()
                }
            }
    }

    private func imagePoint(from viewPoint: CGPoint, fit: CGRect) -> CGPoint {
        guard fit.width > 0, fit.height > 0 else { return .zero }
        let x = (viewPoint.x - fit.minX) / fit.width * model.imageWidth
        let y = (viewPoint.y - fit.minY) / fit.height * model.imageHeight
        return CGPoint(x: min(max(x, 0), model.imageWidth),
                       y: min(max(y, 0), model.imageHeight))
    }

    private func drawAnnotations(context: inout GraphicsContext, fit: CGRect) {
        let scaleX = fit.width / max(model.imageWidth, 1)
        let scaleY = fit.height / max(model.imageHeight, 1)

        var transformed = context
        transformed.translateBy(x: fit.minX, y: fit.minY)
        transformed.scaleBy(x: scaleX, y: scaleY)

        let all = model.annotations + (model.draft.map { [$0] } ?? [])
        for annotation in all {
            draw(annotation, context: &transformed)
        }

        if let crop = model.cropRect {
            let scaled = CGRect(x: fit.minX + crop.minX * scaleX,
                                y: fit.minY + crop.minY * scaleY,
                                width: crop.width * scaleX,
                                height: crop.height * scaleY)
            context.fill(Path(CGRect(x: 0, y: 0, width: fit.minX, height: fit.height)),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.maxX, y: 0, width: 10000, height: 10000)),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.minX, y: fit.minY, width: fit.width, height: max(scaled.minY - fit.minY, 0))),
                         with: .color(.black.opacity(0.28)))
            context.fill(Path(CGRect(x: fit.minX, y: scaled.maxY, width: fit.width, height: max(fit.maxY - scaled.maxY, 0))),
                         with: .color(.black.opacity(0.28)))
            context.stroke(Path(scaled), with: .color(ShotUI.accent), lineWidth: 2)
        }
    }

    private func draw(_ annotation: CaptureAnnotation, context: inout GraphicsContext) {
        let color = Color(nsColor: annotation.color)
        let lineWidth = annotation.lineWidth

        switch annotation.tool {
        case .rectangle:
            let rect = normRect(annotation.start, annotation.end)
            context.stroke(Path(rect), with: .color(color), lineWidth: lineWidth)
        case .filledRectangle:
            context.fill(Path(normRect(annotation.start, annotation.end)),
                         with: .color(color.opacity(0.9)))
        case .ellipse:
            let rect = normRect(annotation.start, annotation.end)
            context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: lineWidth)
        case .line:
            var path = Path()
            path.move(to: annotation.start)
            path.addLine(to: annotation.end)
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        case .arrow:
            var path = Path()
            path.move(to: annotation.start)
            path.addLine(to: annotation.end)
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
            let head = arrowHead(from: annotation.start, to: annotation.end, width: lineWidth)
            var headPath = Path()
            if let first = head.first {
                headPath.move(to: first)
                for point in head.dropFirst() { headPath.addLine(to: point) }
                headPath.closeSubpath()
            }
            context.fill(headPath, with: .color(color))
        case .pen, .marker:
            let points = annotation.points.isEmpty
                ? [annotation.start, annotation.end] : annotation.points
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(path,
                           with: .color(annotation.tool == .marker ? color.opacity(0.35) : color),
                           lineWidth: annotation.tool == .marker ? lineWidth * 2.5 : lineWidth)
        case .text:
            let text = Text(annotation.text ?? "")
                .font(.system(size: annotation.fontSize, weight: .semibold))
                .foregroundColor(color)
            context.draw(text, at: annotation.start, anchor: .topLeading)
        case .number:
            let radius = max(14, annotation.fontSize * 0.9)
            let rect = CGRect(x: annotation.start.x - radius,
                              y: annotation.start.y - radius,
                              width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            let label = Text("\(annotation.number ?? 1)")
                .font(.system(size: annotation.fontSize, weight: .bold))
                .foregroundColor(.white)
            context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
        case .pixelate:
            let rect = normRect(annotation.start, annotation.end)
            context.fill(Path(rect), with: .color(.gray.opacity(0.55)))
            var x = rect.minX
            while x < rect.maxX {
                var y = rect.minY
                while y < rect.maxY {
                    let block = CGRect(x: x, y: y,
                                       width: min(10, rect.maxX - x),
                                       height: min(10, rect.maxY - y))
                    context.stroke(Path(block), with: .color(.black.opacity(0.12)), lineWidth: 0.5)
                    y += 10
                }
                x += 10
            }
        case .blur:
            let rect = normRect(annotation.start, annotation.end)
            context.fill(Path(rect), with: .color(.gray.opacity(0.65)))
        case .highlight:
            let region = normRect(annotation.start, annotation.end)
            context.fill(Path(CGRect(x: 0, y: 0,
                                     width: 10000, height: 10000)),
                         with: .color(.black.opacity(0.35)))
            context.blendMode = .destinationOut
            context.fill(Path(region), with: .color(.white))
            context.blendMode = .normal
            context.stroke(Path(region), with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        case .measure:
            var path = Path()
            path.move(to: annotation.start)
            path.addLine(to: annotation.end)
            context.stroke(path, with: .color(color), lineWidth: max(1, lineWidth))
            let dx = abs(annotation.end.x - annotation.start.x)
            let dy = abs(annotation.end.y - annotation.start.y)
            let text = Text("\(Int(dx)) × \(Int(dy)) px")
                .font(.system(size: max(11, annotation.fontSize * 0.55), weight: .medium))
                .foregroundColor(.white)
            context.draw(text,
                         at: CGPoint(x: (annotation.start.x + annotation.end.x) / 2,
                                     y: (annotation.start.y + annotation.end.y) / 2),
                         anchor: .bottom)
        case .crop:
            break
        }
    }

    private func normRect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private func arrowHead(from start: CGPoint, to end: CGPoint, width: CGFloat) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 1)
        let ux = dx / length
        let uy = dy / length
        let headLength = min(max(width * 4.5, 12), length * 0.6)
        let headWidth = headLength * 0.62
        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        return [end,
                CGPoint(x: base.x - uy * headWidth, y: base.y + ux * headWidth),
                CGPoint(x: base.x + uy * headWidth, y: base.y - ux * headWidth)]
    }

    private func commitText() {
        if let point = pendingTextPoint {
            model.addText(textValue, at: point)
        }
        showingText = false
        pendingTextPoint = nil
    }

    private func fitRect(imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(1, min(container.width / imageSize.width,
                               container.height / imageSize.height))
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: container.midX - size.width / 2,
                      y: container.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
}

private struct GripDots: View {
    var body: some View {
        Canvas { context, _ in
            let dot: CGFloat = 2
            let gap: CGFloat = 2
            for column in 0..<2 {
                for row in 0..<3 {
                    let rect = CGRect(x: CGFloat(column) * (dot + gap),
                                      y: CGFloat(row) * (dot + gap),
                                      width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(.white.opacity(0.4)))
                }
            }
        }
        .frame(width: 6, height: 10)
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct ChromeButton: View {
    let symbol: String
    let title: String
    var size: CGFloat = ShotUI.button
    var iconSize: CGFloat = 14
    var radius: CGFloat = ShotUI.radius
    var disabled: Bool = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(hovering && !disabled ? Color.white.opacity(0.12) : Color.clear)
                )
                .foregroundStyle(ShotUI.icon.opacity(disabled ? 0.3 : 0.9))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
        .onHover { hovering = $0 }
    }
}

private struct EditorToolButton: View {
    let tool: CaptureTool
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: ShotUI.button, height: ShotUI.button)
                .background(
                    RoundedRectangle(cornerRadius: ShotUI.radius, style: .continuous)
                        .fill(selected
                              ? ShotUI.accent
                              : (hovering ? Color.white.opacity(0.12) : Color.clear))
                )
                .foregroundStyle(ShotUI.icon.opacity(selected ? 1 : 0.9))
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var glyph: some View {
        switch tool {
        case .text:
            // ToolbarButtonView.textIcon: 17pt bold "T".
            Text("T")
                .font(.system(size: 17, weight: .bold))
        case .pixelate:
            CheckerboardGlyph()
        case .number:
            Image(systemName: "1.circle.fill")
                .font(.system(size: 14, weight: .medium))
        default:
            Image(systemName: tool.symbol)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

private struct CheckerboardGlyph: View {
    var body: some View {
        Canvas { context, _ in
            let side: CGFloat = 16
            let cell = side / 4
            let clip = Path(roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                            cornerRadius: 3)
            context.clip(to: clip)
            for row in 0..<4 {
                for column in 0..<4 {
                    let rect = CGRect(x: CGFloat(column) * cell,
                                      y: CGFloat(row) * cell,
                                      width: cell, height: cell)
                    let dark = (row + column) % 2 == 0
                    context.fill(Path(rect),
                                 with: .color(.white.opacity(dark ? 1 : 0.35)))
                }
            }
        }
        .frame(width: 16, height: 16)
    }
}
