import AppKit
import CoreImage

enum ImageEffectPreset: String, CaseIterable, Identifiable {
    case none, noir, mono, sepia, chrome, fade, instant, vivid, invert
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "原图"
        case .noir: return "Noir"
        case .mono: return "Mono"
        case .sepia: return "Sepia"
        case .chrome: return "Chrome"
        case .fade: return "Fade"
        case .instant: return "Instant"
        case .vivid: return "Vivid"
        case .invert: return "反色"
        }
    }
}

enum ImageEffectsPipeline {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func apply(_ image: CGImage,
                      brightness: Double,
                      contrast: Double,
                      saturation: Double,
                      sharpness: Double,
                      preset: ImageEffectPreset) -> CGImage {
        var ci = CIImage(cgImage: image)
        let extent = ci.extent

        if brightness != 0 || contrast != 1 || saturation != 1 {
            let f = CIFilter(name: "CIColorControls")!
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(brightness, forKey: kCIInputBrightnessKey)
            f.setValue(contrast, forKey: kCIInputContrastKey)
            f.setValue(saturation, forKey: kCIInputSaturationKey)
            ci = f.outputImage ?? ci
        }
        if sharpness > 0 {
            let f = CIFilter(name: "CISharpenLuminance")!
            f.setValue(ci, forKey: kCIInputImageKey)
            f.setValue(sharpness, forKey: kCIInputSharpnessKey)
            ci = f.outputImage ?? ci
        }
        if let presetFilter = filterName(for: preset) {
            let f = CIFilter(name: presetFilter)!
            f.setValue(ci, forKey: kCIInputImageKey)
            ci = f.outputImage ?? ci
        }
        ci = ci.cropped(to: extent)
        return context.createCGImage(ci, from: extent) ?? image
    }

    private static func filterName(for preset: ImageEffectPreset) -> String? {
        switch preset {
        case .none: return nil
        case .noir: return "CIPhotoEffectNoir"
        case .mono: return "CIPhotoEffectMono"
        case .sepia: return "CISepiaTone"
        case .chrome: return "CIPhotoEffectChrome"
        case .fade: return "CIPhotoEffectFade"
        case .instant: return "CIPhotoEffectInstant"
        case .vivid: return "CIPhotoEffectProcess"
        case .invert: return "CIColorInvert"
        }
    }
}

enum BeautifyComposer {
    private static let baseGradients: [[NSColor]] = [
        [NSColor(srgbRed: 0.16, green: 0.18, blue: 0.24, alpha: 1),
         NSColor(srgbRed: 0.34, green: 0.24, blue: 0.48, alpha: 1)],
        [NSColor(srgbRed: 0.98, green: 0.52, blue: 0.36, alpha: 1),
         NSColor(srgbRed: 0.92, green: 0.28, blue: 0.52, alpha: 1)],
        [NSColor(srgbRed: 0.18, green: 0.62, blue: 0.86, alpha: 1),
         NSColor(srgbRed: 0.10, green: 0.82, blue: 0.66, alpha: 1)],
        [NSColor(srgbRed: 0.96, green: 0.84, blue: 0.46, alpha: 1),
         NSColor(srgbRed: 0.93, green: 0.46, blue: 0.36, alpha: 1)],
        [NSColor(srgbRed: 0.10, green: 0.10, blue: 0.12, alpha: 1),
         NSColor(srgbRed: 0.28, green: 0.28, blue: 0.32, alpha: 1)],
        [NSColor(srgbRed: 0.72, green: 0.82, blue: 0.98, alpha: 1),
         NSColor(srgbRed: 0.93, green: 0.72, blue: 0.86, alpha: 1)]
    ]

    static let gradients: [[NSColor]] = baseGradients + (0..<24).map { i in
        let h = CGFloat(i) / 24
        let a = NSColor(hue: h, saturation: 0.55, brightness: 0.85, alpha: 1)
        let b = NSColor(hue: (h + 0.08).truncatingRemainder(dividingBy: 1),
                        saturation: 0.75, brightness: 0.55, alpha: 1)
        return [a, b]
    }

    static func compose(_ image: CGImage, padding: CGFloat, corner: CGFloat,
                        shadow: Bool, gradient: Int, windowChrome: Bool = false) -> CGImage {
        let w = CGFloat(image.width) + padding * 2
        let h = CGFloat(image.height) + padding * 2
        guard let ctx = CGContext(data: nil, width: Int(w), height: Int(h),
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        let colors = gradients[max(0, min(gradient, gradients.count - 1))].map(\.cgColor) as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: h),
                                   end: CGPoint(x: w, y: 0), options: [])
        }
        let rect = CGRect(x: padding, y: padding,
                          width: CGFloat(image.width), height: CGFloat(image.height))
        let previous = NSGraphicsContext.current
        let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = graphics
        let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)
        if shadow {
            NSGraphicsContext.saveGraphicsState()
            let s = NSShadow()
            s.shadowOffset = NSSize(width: 0, height: -16)
            s.shadowBlurRadius = 36
            s.shadowColor = NSColor.black.withAlphaComponent(0.45)
            s.set()
            NSColor.white.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        path.addClip()
        NSImage(cgImage: image, size: rect.size)
            .draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        if windowChrome {
            let barHeight: CGFloat = min(22, rect.height * 0.12)
            let bar = CGRect(x: rect.minX, y: rect.maxY - barHeight,
                             width: rect.width, height: barHeight)
            NSColor(white: 0.14, alpha: 0.92).setFill()
            NSBezierPath(roundedRect: bar, xRadius: corner, yRadius: corner).fill()
            NSColor(white: 0.78, alpha: 1).setFill()
            for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                c.setFill()
                NSBezierPath(ovalIn: CGRect(x: bar.minX + 8 + CGFloat(i) * 12,
                                            y: bar.midY - 4, width: 8, height: 8)).fill()
            }
        }
        NSGraphicsContext.current = previous
        return ctx.makeImage() ?? image
    }
}
