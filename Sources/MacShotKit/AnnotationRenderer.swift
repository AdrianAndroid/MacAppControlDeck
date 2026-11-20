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

    static func textAttributes(_ annotation: CaptureAnnotation,
                               color: NSColor) -> [NSAttributedString.Key: Any] {
        var font = NSFont.systemFont(ofSize: annotation.fontSize,
                                     weight: annotation.textBold ? .semibold : .regular)
        var traits: NSFontTraitMask = []
        if annotation.textItalic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            font = NSFontManager.shared.convert(font, toHaveTrait: traits)
        }
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        if annotation.textUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if annotation.textStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        let paragraph = NSMutableParagraphStyle()
        switch annotation.textAlign {
        case .left: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        }
        attrs[.paragraphStyle] = paragraph
        return attrs
    }

    static func textSize(_ text: String, annotation: CaptureAnnotation) -> CGSize {
        let attrs = textAttributes(annotation, color: .white)
        return (text as NSString).size(withAttributes: attrs)
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

        let bounds = annotation.unrotatedBounds.offsetBy(dx: -cropOrigin.x, dy: -cropOrigin.y)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        NSGraphicsContext.saveGraphicsState()
        if annotation.rotation != 0 {
            let transform = NSAffineTransform()
            transform.translateX(by: center.x, yBy: center.y)
            transform.rotate(byDegrees: annotation.rotation * 180 / .pi)
            transform.translateX(by: -center.x, yBy: -center.y)
            transform.concat()
        }
        defer { NSGraphicsContext.restoreGraphicsState() }

        color.setStroke()
        color.setFill()

        switch annotation.tool {
        case .select, .eyedropper, .crop:
            break

        case .rectangle, .filledRectangle, .ellipse:
            let r = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
            guard r.width > 0, r.height > 0 else { break }
            let path: NSBezierPath
            if annotation.tool == .ellipse {
                path = NSBezierPath(ovalIn: r)
            } else if annotation.cornerRadius > 0 {
                path = NSBezierPath(roundedRect: r, xRadius: annotation.cornerRadius,
                                    yRadius: annotation.cornerRadius)
            } else {
                path = NSBezierPath(rect: r)
            }
            path.lineWidth = annotation.lineWidth
            let mode: ShapeFillMode = annotation.tool == .filledRectangle
                ? (annotation.fillMode == .stroke ? .fill : annotation.fillMode)
                : annotation.fillMode
            if mode == .fill || mode == .strokeAndFill {
                color.withAlphaComponent(color.alphaComponent * 0.9).setFill()
                path.fill()
            }
            if mode == .stroke || mode == .strokeAndFill {
                color.setStroke()
                path.stroke()
            }

        case .line:
            drawLine(start, end, width: annotation.lineWidth, color: color)

        case .arrow:
            drawArrow(annotation, start: start, end: end, color: color)

        case .pen, .marker:
            let points = annotation.points.isEmpty ? [start, end] : annotation.points.map {
                CGPoint(x: $0.x - cropOrigin.x, y: $0.y - cropOrigin.y)
            }
            guard let first = points.first else { break }
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
            guard !text.isEmpty else { break }
            let attrs = textAttributes(annotation, color: color)
            let size = (text as NSString).size(withAttributes: attrs)
            var origin = start
            switch annotation.textAlign {
            case .left: origin.x = start.x
            case .center: origin.x = start.x - size.width / 2
            case .right: origin.x = start.x - size.width
            }
            if annotation.textBackground {
                let bg = CGRect(x: origin.x - 4, y: origin.y - 2,
                                width: size.width + 8, height: size.height + 4)
                annotation.textBackgroundColor.withAlphaComponent(0.72).setFill()
                NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
            }
            (text as NSString).draw(at: origin, withAttributes: attrs)

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
            guard region.width > 2, region.height > 2 else { break }
            NSColor.black.withAlphaComponent(0.55).setFill()
            NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY,
                                      width: rect.width, height: region.minY - rect.minY)).fill()
            NSBezierPath(rect: CGRect(x: rect.minX, y: region.maxY,
                                      width: rect.width, height: rect.maxY - region.maxY)).fill()
            NSBezierPath(rect: CGRect(x: region.minX, y: region.minY,
                                      width: region.minX - rect.minX, height: region.height)).fill()
            NSBezierPath(rect: CGRect(x: region.maxX, y: region.minY,
                                      width: rect.maxX - region.maxX, height: region.height)).fill()
            NSColor.white.withAlphaComponent(0.85).setStroke()
            let border = NSBezierPath(rect: region)
            border.lineWidth = 1.5
            border.stroke()

        case .measure:
            drawLine(start, end, width: max(1, annotation.lineWidth), color: color)
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

        case .loupe:
            drawLoupe(annotation, start: start, end: end,
                      cropOrigin: cropOrigin, source: source)

        case .stamp:
            let text = annotation.stampEmoji as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: max(20, annotation.fontSize * 1.6))
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: start.x - size.width / 2,
                                  y: start.y - size.height / 2),
                      withAttributes: attrs)
        }
    }

    private static func drawLine(_ start: CGPoint, _ end: CGPoint,
                                 width: CGFloat, color: NSColor) {
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }

    private static func drawArrow(_ annotation: CaptureAnnotation,
                                  start: CGPoint, end: CGPoint,
                                  color: NSColor) {
        let from = annotation.arrowReversed ? end : start
        let to = annotation.arrowReversed ? start : end
        let width = annotation.lineWidth

        switch annotation.arrowStyle {
        case .single, .tail:
            drawLine(start, end, width: width, color: color)
            drawArrowHead(from: from, to: to, width: width, color: color, filled: true)
            if annotation.arrowStyle == .tail {
                let dx = to.x - from.x, dy = to.y - from.y
                let len = max(hypot(dx, dy), 1)
                let ux = dx / len, uy = dy / len
                let base = CGPoint(x: from.x + ux * min(18, len * 0.4),
                                   y: from.y + uy * min(18, len * 0.4))
                let w = width * 3
                drawLine(from, CGPoint(x: base.x - uy * w, y: base.y + ux * w),
                         width: width, color: color)
                drawLine(from, CGPoint(x: base.x + uy * w, y: base.y - ux * w),
                         width: width, color: color)
            }

        case .thick:
            let dx = to.x - from.x, dy = to.y - from.y
            let len = max(hypot(dx, dy), 1)
            let ux = dx / len, uy = dy / len
            let half = max(width * 2.2, 5)
            let headLen = min(max(width * 6, 16), len * 0.45)
            let headHalf = half * 2.1
            let base = CGPoint(x: to.x - ux * headLen, y: to.y - uy * headLen)
            let path = NSBezierPath()
            path.move(to: to)
            path.line(to: CGPoint(x: base.x - uy * headHalf, y: base.y + ux * headHalf))
            path.line(to: CGPoint(x: base.x - uy * half, y: base.y + ux * half))
            path.line(to: CGPoint(x: from.x - uy * half, y: from.y + ux * half))
            path.line(to: CGPoint(x: from.x + uy * half, y: from.y - ux * half))
            path.line(to: CGPoint(x: base.x + uy * half, y: base.y - ux * half))
            path.line(to: CGPoint(x: base.x + uy * headHalf, y: base.y - ux * headHalf))
            path.close()
            color.setFill()
            path.fill()

        case .double:
            drawLine(start, end, width: width, color: color)
            drawArrowHead(from: start, to: end, width: width, color: color, filled: true)
            drawArrowHead(from: end, to: start, width: width, color: color, filled: true)

        case .open:
            drawLine(start, end, width: width, color: color)
            drawArrowHead(from: from, to: to, width: width, color: color, filled: false)
        }
    }

    private static func drawArrowHead(from start: CGPoint, to end: CGPoint,
                                      width: CGFloat, color: NSColor, filled: Bool) {
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

        if filled {
            let path = NSBezierPath()
            path.move(to: end)
            path.line(to: left)
            path.line(to: right)
            path.close()
            color.setFill()
            path.fill()
        } else {
            drawLine(end, left, width: max(1, width * 0.8), color: color)
            drawLine(end, right, width: max(1, width * 0.8), color: color)
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

    private static func drawLoupe(_ annotation: CaptureAnnotation,
                                  start: CGPoint, end: CGPoint,
                                  cropOrigin: CGPoint, source: CGImage) {
        let radius = max(24, min(hypot(end.x - start.x, end.y - start.y), 160))
        let sourceCenter = CGPoint(x: annotation.start.x, y: annotation.start.y)
        let sourceRadius = radius / max(annotation.loupeZoom, 0.1)
        let sourceRect = CGRect(x: sourceCenter.x - sourceRadius,
                                y: sourceCenter.y - sourceRadius,
                                width: sourceRadius * 2, height: sourceRadius * 2)
        guard let cropped = source.cropping(to: sourceRect.integral) else { return }
        let dest = CGRect(x: start.x - radius, y: start.y - radius,
                          width: radius * 2, height: radius * 2)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: dest).addClip()
        NSImage(cgImage: cropped, size: dest.size)
            .draw(in: dest, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let ring = NSBezierPath(ovalIn: dest)
        ring.lineWidth = 2
        ring.stroke()
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
