import AppKit
import CoreGraphics
import CoreImage

enum AnnotationRenderer {
    /// 把底图和标注合成为最终图片；cropRect 使用图片左上原点坐标。
    static func render(image: CGImage,
                       annotations: [CaptureAnnotation],
                       cropRect: CGRect? = nil) -> CGImage? {
        let fullRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let crop = (cropRect?.intersection(fullRect) ?? fullRect).integral
        guard crop.width >= 1, crop.height >= 1 else { return nil }
        let outputWidth = Int(crop.width)
        let outputHeight = Int(crop.height)

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        let croppedBase = image.cropping(to: crop) ?? image
        let previous = NSGraphicsContext.current
        let graphics = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = graphics
        defer { NSGraphicsContext.current = previous }

        let outputRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        NSImage(cgImage: croppedBase,
                size: NSSize(width: outputWidth, height: outputHeight))
            .draw(in: outputRect, from: .zero, operation: .copy, fraction: 1)

        for annotation in annotations {
            draw(annotation, in: outputRect, cropOrigin: crop.origin, source: image)
        }

        return context.makeImage()
    }

    private static func draw(_ annotation: CaptureAnnotation,
                             in rect: CGRect,
                             cropOrigin: CGPoint,
                             source: CGImage) {
        let start = CGPoint(x: annotation.start.x - cropOrigin.x,
                            y: annotation.start.y - cropOrigin.y)
        let end = CGPoint(x: annotation.end.x - cropOrigin.x,
                          y: annotation.end.y - cropOrigin.y)
        let color = annotation.color.withAlphaComponent(annotation.color.alphaComponent * annotation.alpha)
        color.setStroke()
        color.setFill()

        switch annotation.tool {
        case .rectangle, .filledRectangle:
            let r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
            guard r.width > 0, r.height > 0 else { return }
            let path = NSBezierPath(rect: r)
            path.lineWidth = annotation.lineWidth
            if annotation.tool == .filledRectangle {
                color.setFill()
                path.fill()
            } else {
                color.setStroke()
                path.stroke()
            }

        case .ellipse:
            let r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
            guard r.width > 0, r.height > 0 else { return }
            let path = NSBezierPath(ovalIn: r)
            path.lineWidth = annotation.lineWidth
            path.stroke()

        case .line, .arrow:
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = annotation.lineWidth
            path.stroke()
            if annotation.tool == .arrow {
                drawArrowHead(from: start, to: end, width: annotation.lineWidth, color: color)
            }

        case .pen, .marker:
            let points = annotation.points.isEmpty ? [start, end] : annotation.points.map {
                CGPoint(x: $0.x - cropOrigin.x, y: $0.y - cropOrigin.y)
            }
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.move(to: first)
            for point in points.dropFirst() { path.line(to: point) }
            path.lineWidth = annotation.tool == .marker
                ? annotation.lineWidth * 2.5
                : annotation.lineWidth
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            (annotation.tool == .marker
                ? color.withAlphaComponent(0.35)
                : color).setStroke()
            path.stroke()

        case .text:
            let text = annotation.text ?? ""
            guard !text.isEmpty else { return }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .semibold),
                .foregroundColor: color
            ]
            (text as NSString).draw(at: start, withAttributes: attributes)

        case .number:
            let value = annotation.number ?? 1
            let radius: CGFloat = max(14, annotation.fontSize * 0.9)
            let circleRect = CGRect(x: start.x - radius, y: start.y - radius,
                                    width: radius * 2, height: radius * 2)
            let circle = NSBezierPath(ovalIn: circleRect)
            color.setFill()
            circle.fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: annotation.fontSize),
                .foregroundColor: NSColor.white
            ]
            let label = "\(value)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: circleRect.midX - size.width / 2,
                                   y: circleRect.midY - size.height / 2),
                       withAttributes: attributes)

        case .pixelate:
            drawPixelate(annotation, in: rect, cropOrigin: cropOrigin, source: source)

        case .blur:
            drawBlur(annotation, in: rect, cropOrigin: cropOrigin, source: source)

        case .highlight:
            let region = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                                width: abs(end.x - start.x), height: abs(end.y - start.y))
                .intersection(rect)
            guard region.width > 2, region.height > 2 else { return }
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY,
                                      width: rect.width, height: region.minY - rect.minY)).fill()
            NSBezierPath(rect: CGRect(x: rect.minX, y: region.maxY,
                                      width: rect.width, height: rect.maxY - region.maxY)).fill()
            NSBezierPath(rect: CGRect(x: rect.minX, y: region.minY,
                                      width: region.minX - rect.minX, height: region.height)).fill()
            NSBezierPath(rect: CGRect(x: region.maxX, y: region.minY,
                                      width: rect.maxX - region.maxX, height: region.height)).fill()
            NSColor.white.withAlphaComponent(0.85).setStroke()
            let border = NSBezierPath(rect: region)
            border.lineWidth = 1.5
            border.stroke()

        case .measure:
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = max(1, annotation.lineWidth)
            color.setStroke()
            path.stroke()
            let dx = abs(annotation.end.x - annotation.start.x)
            let dy = abs(annotation.end.y - annotation.start.y)
            let label = "\(Int(dx)) × \(Int(dy)) px"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: max(11, annotation.fontSize * 0.55),
                                                        weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.65)
            ]
            let size = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(at: CGPoint(x: (start.x + end.x) / 2 - size.width / 2,
                                                 y: (start.y + end.y) / 2 - size.height - 6),
                                     withAttributes: attrs)

        case .crop:
            break
        }
    }

    private static func drawBlur(_ annotation: CaptureAnnotation,
                                 in rect: CGRect,
                                 cropOrigin: CGPoint,
                                 source: CGImage) {
        let region = CGRect(x: min(annotation.start.x, annotation.end.x) - cropOrigin.x,
                            y: min(annotation.start.y, annotation.end.y) - cropOrigin.y,
                            width: abs(annotation.end.x - annotation.start.x),
                            height: abs(annotation.end.y - annotation.start.y))
            .intersection(rect)
        guard region.width >= 2, region.height >= 2 else { return }
        let sourceRegion = CGRect(x: region.minX + cropOrigin.x,
                                  y: region.minY + cropOrigin.y,
                                  width: region.width,
                                  height: region.height).integral
        guard let cropped = source.cropping(to: sourceRegion) else { return }
        let ciImage = CIImage(cgImage: cropped)
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 16)
            .cropped(to: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))
        guard let blurred = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }
        NSImage(cgImage: blurred,
                size: NSSize(width: region.width, height: region.height))
            .draw(in: region, from: .zero, operation: .copy, fraction: 1)
    }

    private static func drawArrowHead(from start: CGPoint, to end: CGPoint,
                                      width: CGFloat, color: NSColor) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 1)
        let ux = dx / length
        let uy = dy / length
        let headLength = min(max(width * 4.5, 12), length * 0.6)
        let headWidth = headLength * 0.62

        let base = CGPoint(x: end.x - ux * headLength, y: end.y - uy * headLength)
        let left = CGPoint(x: base.x - uy * headWidth, y: base.y + ux * headWidth)
        let right = CGPoint(x: base.x + uy * headWidth, y: base.y - ux * headWidth)

        let path = NSBezierPath()
        path.move(to: end)
        path.line(to: left)
        path.line(to: right)
        path.close()
        color.setFill()
        path.fill()
    }

    private static func drawPixelate(_ annotation: CaptureAnnotation,
                                     in rect: CGRect,
                                     cropOrigin: CGPoint,
                                     source: CGImage) {
        let region = CGRect(x: min(annotation.start.x, annotation.end.x) - cropOrigin.x,
                            y: min(annotation.start.y, annotation.end.y) - cropOrigin.y,
                            width: abs(annotation.end.x - annotation.start.x),
                            height: abs(annotation.end.y - annotation.start.y))
            .intersection(rect)
        guard region.width >= 2, region.height >= 2 else { return }

        let bitmap = NSBitmapImageRep(cgImage: source)
        let block = max(CGFloat(8), annotation.lineWidth * 3)
        let sourceRegion = region.offsetBy(dx: cropOrigin.x, dy: cropOrigin.y)

        var y = sourceRegion.minY
        while y < sourceRegion.maxY {
            var x = sourceRegion.minX
            while x < sourceRegion.maxX {
                let sampleX = min(Int(x + block / 2), source.width - 1)
                let sampleY = min(Int(y + block / 2), source.height - 1)
                let bottomY = max(0, min(source.height - 1, source.height - 1 - sampleY))
                let color = bitmap.colorAt(x: sampleX, y: bottomY) ?? .black
                color.setFill()
                NSBezierPath(rect: CGRect(x: x - cropOrigin.x, y: y - cropOrigin.y,
                                          width: block, height: block)).fill()
                x += block
            }
            y += block
        }
    }
}
