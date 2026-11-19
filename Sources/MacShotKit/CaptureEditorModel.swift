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

    private var undoStack: [[CaptureAnnotation]] = []
    private var redoStack: [[CaptureAnnotation]] = []
    private var nextNumber = 1

    init(image: CGImage) {
        baseImage = image
    }

    var imageWidth: CGFloat { CGFloat(baseImage.width) }
    var imageHeight: CGFloat { CGFloat(baseImage.height) }
    var nsColor: NSColor { NSColor(color).usingColorSpace(.sRGB) ?? .systemRed }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func beginDraft(at point: CGPoint) {
        guard tool != .crop else {
            cropRect = CGRect(origin: point, size: .zero)
            return
        }
        guard tool != .text else { return }
        var annotation = CaptureAnnotation(tool: tool,
                                           start: point,
                                           end: point,
                                           color: nsColor,
                                           lineWidth: lineWidth)
        if tool == .pen || tool == .marker {
            annotation.points = [point]
        }
        if tool == .number {
            annotation.number = nextNumber
        }
        draft = annotation
    }

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
        if tool == .crop {
            return
        }
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
        isDirty = true
    }

    func addText(_ text: String, at point: CGPoint) {
        guard !text.isEmpty else { return }
        pushUndo()
        annotations.append(CaptureAnnotation(tool: .text,
                                            start: point,
                                            end: point,
                                            color: nsColor,
                                            lineWidth: lineWidth,
                                            text: text,
                                            fontSize: max(18, lineWidth * 7)))
        isDirty = true
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = last
        draft = nil
        isDirty = true
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = next
        draft = nil
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
        // 裁剪会改变底图，旧快照只包含标注，继续撤销会把标注贴回错误的底图。
        // 裁剪后清空撤销栈，避免产生错位结果。
        undoStack.removeAll()
        redoStack.removeAll()
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
        AnnotationRenderer.render(image: baseImage,
                                  annotations: annotations,
                                  cropRect: cropRect)
    }

    private func pushUndo() {
        undoStack.append(annotations)
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
    }
}
