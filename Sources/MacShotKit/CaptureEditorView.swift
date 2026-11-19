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
            toolbar
            Divider()
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Color(nsColor: .windowBackgroundColor)
                    imageAndCanvas(size: proxy.size)
                }
                .clipped()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
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

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(CaptureTool.allCases) { tool in
                    Button {
                        model.tool = tool
                        if tool != .crop { model.cropRect = nil }
                    } label: {
                        Image(systemName: tool.symbol)
                            .frame(width: 26, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .tint(model.tool == tool ? .accentColor : .secondary)
                    .help(tool.title)
                }
                Spacer(minLength: 8)
                ColorPicker("", selection: $model.color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 34)
                Slider(value: $model.lineWidth, in: 1...14)
                    .frame(width: 90)
                Text("\(Int(model.lineWidth))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 18)
            }

            HStack(spacing: 8) {
                Button("撤销", systemImage: "arrow.uturn.backward") { model.undo() }
                    .disabled(!model.canUndo)
                Button("重做", systemImage: "arrow.uturn.forward") { model.redo() }
                    .disabled(!model.canRedo)
                if model.tool == .crop {
                    Button("应用裁剪", systemImage: "crop") { model.applyCrop() }
                        .disabled(model.cropRect == nil)
                    Button("取消裁剪") { model.resetCrop() }
                        .disabled(model.cropRect == nil)
                }
                Spacer()
                Button("保存", systemImage: "square.and.arrow.down") {
                    if let image = model.render() { onSave(image) }
                }
                Button("复制", systemImage: "doc.on.doc") {
                    if let image = model.render() { onCopy(image) }
                }
                Button("钉图", systemImage: "pin") {
                    if let image = model.render() { onPin(image) }
                }
                Button("OCR", systemImage: "text.viewfinder") {
                    if let image = model.render() { onOCR(image) }
                }
                Button("关闭", systemImage: "xmark") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func imageAndCanvas(size: CGSize) -> some View {
        let fit = fitRect(imageSize: CGSize(width: model.imageWidth, height: model.imageHeight),
                          in: size)
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

    private func fitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width,
                        container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2,
                      y: (container.height - size.height) / 2,
                      width: size.width, height: size.height)
    }
}
