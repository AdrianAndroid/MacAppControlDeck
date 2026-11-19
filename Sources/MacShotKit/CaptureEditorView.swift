import AppKit
import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            dragStrip
            canvasArea
            bottomBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .frame(minWidth: 680, minHeight: 420)
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

    private var dragStrip: some View {
        WindowDragHandle()
            .frame(height: 16)
    }

    private var canvasArea: some View {
        GeometryReader { proxy in
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                imageAndCanvas(size: proxy.size)
            }
            .clipped()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
            HStack(spacing: 3) {
                toolGroup([.rectangle, .filledRectangle, .ellipse, .line, .arrow])
                separator
                toolGroup([.pen, .marker])
                separator
                toolGroup([.text, .number])
                separator
                toolGroup([.pixelate, .blur, .highlight, .measure, .crop])

                Spacer(minLength: 6)

                ColorPicker("", selection: $model.color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 24, height: 24)
                    .help("颜色")

                Image(systemName: "lineweight")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Slider(value: $model.lineWidth, in: 1...14)
                    .frame(width: 62)
                    .controlSize(.mini)
                Text("\(Int(model.lineWidth))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                separator

                actionButton("arrow.uturn.backward", "撤销", disabled: !model.canUndo) {
                    model.undo()
                }
                actionButton("arrow.uturn.forward", "重做", disabled: !model.canRedo) {
                    model.redo()
                }

                separator

                if model.tool == .crop {
                    actionButton("checkmark", "应用裁剪", disabled: model.cropRect == nil) {
                        model.applyCrop()
                    }
                    actionButton("xmark", "取消裁剪", disabled: model.cropRect == nil) {
                        model.resetCrop()
                    }
                }
                actionButton("square.and.arrow.down", "保存", primary: true) {
                    if let image = model.render() { onSave(image) }
                }
                actionButton("doc.on.doc", "复制") {
                    if let image = model.render() { onCopy(image) }
                }
                actionButton("pin", "钉图") {
                    if let image = model.render() { onPin(image) }
                }
                actionButton("text.viewfinder", "OCR") {
                    if let image = model.render() { onOCR(image) }
                }
                actionButton("xmark", "关闭") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
        }
        .background(.ultraThinMaterial)
    }

    private func toolGroup(_ tools: [CaptureTool]) -> some View {
        HStack(spacing: 2) {
            ForEach(tools) { tool in
                EditorToolButton(tool: tool,
                                 selected: model.tool == tool) {
                    model.tool = tool
                    if tool != .crop { model.cropRect = nil }
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    private func actionButton(_ symbol: String,
                              _ title: String,
                              disabled: Bool = false,
                              primary: Bool = false,
                              action: @escaping () -> Void) -> some View {
        EditorActionButton(symbol: symbol,
                           title: title,
                           disabled: disabled,
                           primary: primary,
                           action: action)
    }

    private func imageAndCanvas(size: CGSize) -> some View {
        let inset: CGFloat = 14
        let container = CGRect(x: inset, y: inset,
                               width: max(size.width - inset * 2, 1),
                               height: max(size.height - inset * 2, 1))
        let fit = fitRect(imageSize: CGSize(width: model.imageWidth, height: model.imageHeight),
                          in: container)
        return ZStack(alignment: .topLeading) {
            Image(nsImage: NSImage(cgImage: model.baseImage,
                                   size: NSSize(width: model.imageWidth, height: model.imageHeight)))
                .resizable()
                .interpolation(.high)
                .frame(width: fit.width, height: fit.height)
                .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 7)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
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
            context.stroke(Path(scaled), with: .color(.accentColor), lineWidth: 2)
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
        let scale = min(container.width / imageSize.width,
                        container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: container.midX - size.width / 2,
                      y: container.midY - size.height / 2,
                      width: size.width, height: size.height)
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

private struct EditorToolButton: View {
    let tool: CaptureTool
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            glyph
                .frame(width: 27, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected
                              ? Color.accentColor.opacity(0.18)
                              : (hovering ? Color.primary.opacity(0.06) : Color.clear))
                )
                .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.78))
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var glyph: some View {
        switch tool {
        case .text:
            Text("T")
                .font(.system(size: 13, weight: .semibold, design: .serif))
        case .number:
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.55), lineWidth: 1)
                    .frame(width: 15, height: 15)
                Text("1")
                    .font(.system(size: 9, weight: .semibold))
            }
        default:
            Image(systemName: tool.symbol)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

private struct EditorActionButton: View {
    let symbol: String
    let title: String
    let disabled: Bool
    let primary: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(primary
                              ? Color.accentColor
                              : (hovering && !disabled ? Color.primary.opacity(0.08) : Color.clear))
                )
                .foregroundStyle(primary ? Color.white : Color.primary.opacity(disabled ? 0.28 : 0.76))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(title)
        .onHover { hovering = $0 }
    }
}
