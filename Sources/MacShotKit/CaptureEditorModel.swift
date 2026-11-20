import AppKit
import Combine
import SwiftUI

final class CaptureEditorModel: ObservableObject {
    @Published var baseImage: CGImage
    @Published var annotations: [CaptureAnnotation] = []
    @Published var tool: CaptureTool = .rectangle
    @Published var color: Color = .red
    @Published var lineWidth: CGFloat = 3
    @Published var draft: CaptureAnnotation?
    @Published var cropRect: CGRect?
    @Published var isDirty = false
    @Published var selectedID: UUID?
    @Published var pickedColorText: String?

    // Advanced style defaults
    @Published var arrowStyle: ArrowStyle = .single
    @Published var arrowReversed = false
    @Published var fillMode: ShapeFillMode = .stroke
    @Published var cornerRadius: CGFloat = 0
    @Published var textBold = true
    @Published var textItalic = false
    @Published var textUnderline = false
    @Published var textStrikethrough = false
    @Published var textAlign: TextAlign = .left
    @Published var textBackground = false
    @Published var textOutline = false
    @Published var textBackgroundColor: Color = .black
    @Published var stampEmoji = "😀"
    @Published var loupeZoom: CGFloat = 2
    @Published var censorMode: CensorMode = .pixelate
    @Published var numberFormat: NumberFormat = .arabic
    @Published var measureUnit: MeasureUnit = .pixel
    @Published var measureScale: CGFloat = 0
    @Published var annotationAlpha: CGFloat = 1
    @Published var lineStyle: LineStyle = .solid
    @Published var fontName: String = ""
    @Published var spotlightDim: CGFloat = 0.55

    // Image effects / Beautify
    @Published var brightness: Double = 0
    @Published var contrast: Double = 1
    @Published var saturation: Double = 1
    @Published var sharpness: Double = 0
    @Published var effectPreset: ImageEffectPreset = .none
    @Published var beautifyEnabled = false
    @Published var beautifyPadding: CGFloat = 48
    @Published var beautifyCorner: CGFloat = 12
    @Published var beautifyShadow = true
    @Published var beautifyGradient = 0
    @Published var beautifyWindowChrome = false
    @Published var outputWidth = 0
    @Published var outputHeight = 0
    @Published var outputScale: CGFloat = 2

    private var undoStack: [[CaptureAnnotation]] = []
    private var redoStack: [[CaptureAnnotation]] = []
    private var nextNumber = 1
    private var lastSelectPoint: CGPoint?
    private var selectStartBounds: CGRect?

    init(image: CGImage, annotations: [CaptureAnnotation] = []) {
        baseImage = image
        self.annotations = annotations
    }

    var imageWidth: CGFloat { CGFloat(baseImage.width) }
    var imageHeight: CGFloat { CGFloat(baseImage.height) }
    var nsColor: NSColor { NSColor(color).usingColorSpace(.sRGB) ?? .systemRed }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var selectedAnnotation: CaptureAnnotation? {
        guard let selectedID else { return nil }
        return annotations.first { $0.id == selectedID }
    }
    var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return annotations.firstIndex { $0.id == selectedID }
    }

    func beginDraft(at point: CGPoint) {
        guard tool != .crop else {
            cropRect = CGRect(origin: point, size: .zero)
            return
        }
        guard tool != .text, tool != .select, tool != .eyedropper else { return }
        var annotation = CaptureAnnotation(tool: tool,
                                           start: point,
                                           end: point,
                                           color: nsColor,
                                           lineWidth: lineWidth)
        annotation.arrowStyle = arrowStyle
        annotation.arrowReversed = arrowReversed
        annotation.fillMode = fillMode
        annotation.cornerRadius = cornerRadius
        annotation.textBold = textBold
        annotation.textItalic = textItalic
        annotation.textUnderline = textUnderline
        annotation.textStrikethrough = textStrikethrough
        annotation.textAlign = textAlign
        annotation.textBackground = textBackground
        annotation.textBackgroundColor = NSColor(textBackgroundColor)
        annotation.textOutline = textOutline
        annotation.stampEmoji = stampEmoji
        annotation.censorMode = censorMode
        annotation.numberFormat = numberFormat
        annotation.measureUnit = measureUnit
        annotation.measureScale = measureScale
        annotation.fontName = fontName
        annotation.lineStyle = lineStyle
        annotation.alpha = annotationAlpha
        annotation.spotlightDim = spotlightDim
        if tool == .pen || tool == .marker {
            annotation.points = [point]
        }
        if tool == .number {
            annotation.number = nextNumber
        }
        if tool == .stamp {
            annotation.fontSize = max(fontSizeForStamp(), lineWidth * 8)
        }
        draft = annotation
    }

    private func fontSizeForStamp() -> CGFloat { 28 }

    func updateDraft(to point: CGPoint) {
        if tool == .crop {
            guard let origin = cropRect?.origin else { return }
            cropRect = CGRect(x: min(origin.x, point.x),
                              y: min(origin.y, point.y),
                              width: abs(point.x - origin.x),
                              height: abs(point.y - origin.y))
            return
        }
        guard var draft else { return }
        draft.end = point
        if draft.tool == .pen || draft.tool == .marker {
            draft.points.append(point)
        }
        self.draft = draft
    }

    func commitDraft() {
        if tool == .crop { return }
        guard let draft else { return }
        self.draft = nil

        if draft.tool == .number {
            pushUndo()
            annotations.append(draft)
            nextNumber += 1
            isDirty = true
            return
        }
        guard draft.boundingRect.width > 3 || draft.boundingRect.height > 3
                || draft.points.count > 2 else { return }
        pushUndo()
        annotations.append(draft)
        selectedID = draft.id
        isDirty = true
    }

    func addImage(_ cg: CGImage, at point: CGPoint? = nil) {
        pushUndo()
        let maxW = imageWidth * 0.45
        let scale = min(1, maxW / CGFloat(max(cg.width, 1)))
        let w = CGFloat(cg.width) * scale
        let h = CGFloat(cg.height) * scale
        let origin = point ?? CGPoint(x: (imageWidth - w) / 2, y: (imageHeight - h) / 2)
        var annotation = CaptureAnnotation(tool: .image, start: origin,
                                           end: CGPoint(x: origin.x + w, y: origin.y + h),
                                           color: nsColor, lineWidth: 2)
        annotation.image = cg
        annotations.append(annotation)
        selectedID = annotation.id
        isDirty = true
    }

    func addText(_ text: String, at point: CGPoint) {
        guard !text.isEmpty else { return }
        pushUndo()
        var annotation = CaptureAnnotation(tool: .text,
                                           start: point,
                                           end: point,
                                           color: nsColor,
                                           lineWidth: lineWidth,
                                           text: text,
                                           fontSize: max(18, lineWidth * 7))
        annotation.textBold = textBold
        annotation.textItalic = textItalic
        annotation.textUnderline = textUnderline
        annotation.textStrikethrough = textStrikethrough
        annotation.textAlign = textAlign
        annotation.textBackground = textBackground
        annotation.textBackgroundColor = NSColor(textBackgroundColor)
        annotation.textOutline = textOutline
        annotation.fontName = fontName
        annotation.alpha = annotationAlpha
        annotations.append(annotation)
        selectedID = annotation.id
        isDirty = true
    }

    /// 用当前选中的测量线校准真实比例：`lengthMM` 为用户输入的实际长度（毫米）。
    func calibrateMeasure(lengthMM: CGFloat) {
        guard lengthMM > 0, let annotation = selectedAnnotation ?? annotations.last(where: { $0.tool == .measure }) else { return }
        let pixels = hypot(annotation.end.x - annotation.start.x,
                           annotation.end.y - annotation.start.y)
        guard pixels > 0 else { return }
        measureScale = lengthMM / pixels
        mutateSelectedWithoutUndo { $0.measureScale = self.measureScale }
    }

    func nudgeSelected(dx: CGFloat, dy: CGFloat) {
        guard selectedID != nil else { return }
        mutateSelectedWithoutUndo { $0.move(by: CGPoint(x: dx, y: dy)) }
        isDirty = true
    }

    func updateSelectedText(_ text: String) {
        guard let index = selectedIndex, !text.isEmpty else { return }
        pushUndo()
        annotations[index].text = text
        isDirty = true
    }

    // MARK: - Selection

    @discardableResult
    func select(at point: CGPoint) -> UUID? {
        if let hit = hitTest(point) {
            selectedID = hit.id
            lastSelectPoint = point
            selectStartBounds = hit.unrotatedBounds
            return hit.id
        }
        selectedID = nil
        lastSelectPoint = nil
        selectStartBounds = nil
        return nil
    }

    func hitTest(_ point: CGPoint) -> CaptureAnnotation? {
        for annotation in annotations.reversed() {
            let bounds = annotation.unrotatedBounds
            var p = point
            if annotation.rotation != 0 {
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                let t = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: -annotation.rotation)
                    .translatedBy(x: -center.x, y: -center.y)
                p = point.applying(t)
            }
            if bounds.insetBy(dx: -6, dy: -6).contains(p) { return annotation }
        }
        return nil
    }

    func dragSelected(to point: CGPoint) {
        guard let lastSelectPoint, let index = selectedIndex else { return }
        let delta = CGPoint(x: point.x - lastSelectPoint.x, y: point.y - lastSelectPoint.y)
        annotations[index].move(by: delta)
        self.lastSelectPoint = point
        isDirty = true
    }

    func resizeSelected(original: CaptureAnnotation, to rect: CGRect) {
        guard let index = selectedIndex else { return }
        var copy = original
        copy.resize(to: rect)
        annotations[index] = copy
        isDirty = true
    }

    func resizeSelected(to rect: CGRect) {
        guard let index = selectedIndex else { return }
        var r = rect
        if r.width < 8 { r.size.width = 8 }
        if r.height < 8 { r.size.height = 8 }
        annotations[index].resize(to: r)
        isDirty = true
    }

    func updateSelected(_ mutate: (inout CaptureAnnotation) -> Void) {
        guard let index = selectedIndex else { return }
        pushUndo()
        mutate(&annotations[index])
        isDirty = true
    }

    func mutateSelectedWithoutUndo(_ mutate: (inout CaptureAnnotation) -> Void) {
        guard let index = selectedIndex else { return }
        mutate(&annotations[index])
        isDirty = true
    }

    func deleteSelected() {
        guard let index = selectedIndex else { return }
        pushUndo()
        annotations.remove(at: index)
        selectedID = nil
        isDirty = true
    }

    func selectEnded() {
        lastSelectPoint = nil
        selectStartBounds = nil
    }

    // MARK: - Eyedropper

    func pickColor(at point: CGPoint) {
        let x = min(max(Int(point.x), 0), baseImage.width - 1)
        let y = min(max(Int(point.y), 0), baseImage.height - 1)
        guard let data = baseImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return }
        let bpp = baseImage.bitsPerPixel / 8
        let row = baseImage.bytesPerRow
        let offset = y * row + x * bpp
        let r: UInt8, g: UInt8, b: UInt8
        if baseImage.bitmapInfo.contains(.byteOrder32Little) {
            b = ptr[offset]; g = ptr[offset + 1]; r = ptr[offset + 2]
        } else {
            r = ptr[offset]; g = ptr[offset + 1]; b = ptr[offset + 2]
        }
        let c = NSColor(srgbRed: CGFloat(r) / 255,
                        green: CGFloat(g) / 255,
                        blue: CGFloat(b) / 255, alpha: 1)
        color = Color(nsColor: c)
        pickedColorText = String(format: "R%d G%d B%d  #%02X%02X%02X",
                                r, g, b, r, g, b)
    }

    func copyHexFromPicked() {
        guard let pickedColorText, let hex = pickedColorText.split(separator: "#").last else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("#\(hex)", forType: .string)
    }

    // MARK: - Undo

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = last
        draft = nil
        selectedID = nil
        isDirty = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        draft = nil
        selectedID = nil
        isDirty = true
    }

    func applyCrop() {
        guard let cropRect else { return }
        let full = CGRect(x: 0, y: 0, width: baseImage.width, height: baseImage.height)
        let crop = cropRect.intersection(full).integral
        guard crop.width >= 2, crop.height >= 2,
              let cropped = baseImage.cropping(to: crop) else { return }

        let transformed = annotations.compactMap { annotation -> CaptureAnnotation? in
            var copy = annotation
            copy.start.x -= crop.minX
            copy.start.y -= crop.minY
            copy.end.x -= crop.minX
            copy.end.y -= crop.minY
            copy.points = copy.points.map { CGPoint(x: $0.x - crop.minX, y: $0.y - crop.minY) }
            let bounds = copy.boundingRect.intersection(
                CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
            return bounds.width > 1 && bounds.height > 1 ? copy : nil
        }
        pushUndo()
        baseImage = cropped
        annotations = transformed
        self.cropRect = nil
        tool = .rectangle
        undoStack.removeAll()
        redoStack.removeAll()
        selectedID = nil
        isDirty = true
    }

    func resetCrop() {
        cropRect = nil
    }

    func flipHorizontally() {
        guard let flipped = flipped(baseImage, horizontal: true) else { return }
        baseImage = flipped
        mirrorAnnotations(horizontal: true)
        isDirty = true
        undoStack.removeAll()
        redoStack.removeAll()
    }

    func flipVertically() {
        guard let flipped = flipped(baseImage, horizontal: false) else { return }
        baseImage = flipped
        mirrorAnnotations(horizontal: false)
        isDirty = true
        undoStack.removeAll()
        redoStack.removeAll()
    }

    private func flipped(_ image: CGImage, horizontal: Bool) -> CGImage? {
        let width = image.width
        let height = image.height
        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.translateBy(x: horizontal ? CGFloat(width) : 0,
                            y: horizontal ? 0 : CGFloat(height))
        context.scaleBy(x: horizontal ? -1 : 1, y: horizontal ? 1 : -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func mirrorAnnotations(horizontal: Bool) {
        let width = imageWidth
        let height = imageHeight
        annotations = annotations.map { annotation in
            var copy = annotation
            if horizontal {
                copy.start.x = width - copy.start.x
                copy.end.x = width - copy.end.x
                copy.points = copy.points.map { CGPoint(x: width - $0.x, y: $0.y) }
            } else {
                copy.start.y = height - copy.start.y
                copy.end.y = height - copy.end.y
                copy.points = copy.points.map { CGPoint(x: $0.x, y: height - $0.y) }
            }
            return copy
        }
        if let crop = cropRect {
            cropRect = horizontal
                ? CGRect(x: width - crop.maxX, y: crop.minY, width: crop.width, height: crop.height)
                : CGRect(x: crop.minX, y: height - crop.maxY, width: crop.width, height: crop.height)
        }
    }

    func render() -> CGImage? {
        guard var output = AnnotationRenderer.render(image: baseImage,
                                                     annotations: annotations,
                                                     cropRect: cropRect) else { return nil }
        if effectPreset != .none || brightness != 0 || contrast != 1
            || saturation != 1 || sharpness != 0 {
            output = ImageEffectsPipeline.apply(output,
                                                brightness: brightness,
                                                contrast: contrast,
                                                saturation: saturation,
                                                sharpness: sharpness,
                                                preset: effectPreset)
        }
        if beautifyEnabled {
            output = BeautifyComposer.compose(output,
                                              padding: beautifyPadding,
                                              corner: beautifyCorner,
                                              shadow: beautifyShadow,
                                              gradient: beautifyGradient,
                                              windowChrome: beautifyWindowChrome)
        }
        if outputWidth > 0, outputHeight > 0 {
            output = CaptureExporter.resize(output,
                                            width: outputWidth,
                                            height: outputHeight)
        }
        if outputScale < 1.5 {
            output = CaptureExporter.resize(output,
                                            width: Int(CGFloat(output.width) / 2),
                                            height: Int(CGFloat(output.height) / 2))
        }
        return output
    }

    func previewBaseImage() -> CGImage {
        if effectPreset == .none && brightness == 0 && contrast == 1
            && saturation == 1 && sharpness == 0 { return baseImage }
        return ImageEffectsPipeline.apply(baseImage, brightness: brightness,
                                          contrast: contrast, saturation: saturation,
                                          sharpness: sharpness, preset: effectPreset)
    }

    private func pushUndo() {
        undoStack.append(annotations)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
}
