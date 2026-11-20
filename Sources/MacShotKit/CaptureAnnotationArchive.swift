import AppKit

/// Serialisable form of a CaptureAnnotation, used to keep editable history sessions.
struct CaptureAnnotationArchive: Codable {
    var tool: String
    var start: [Double]
    var end: [Double]
    var points: [[Double]]
    var color: [Double]
    var lineWidth: Double
    var text: String?
    var number: Int?
    var fontSize: Double
    var alpha: Double
    var arrowStyle: String
    var arrowReversed: Bool
    var fillMode: String
    var cornerRadius: Double
    var rotation: Double
    var textBold: Bool
    var textItalic: Bool
    var textUnderline: Bool
    var textStrikethrough: Bool
    var textAlign: String
    var textBackground: Bool
    var textOutline: Bool
    var textBackgroundColor: [Double]
    var stampEmoji: String
    var loupeZoom: Double
    var imageBase64: String?
    var censorMode: String
    var numberFormat: String
    var measureUnit: String
    var spotlightDim: Double

    init(_ a: CaptureAnnotation) {
        tool = a.tool.rawValue
        start = [a.start.x, a.start.y]
        end = [a.end.x, a.end.y]
        points = a.points.map { [$0.x, $0.y] }
        let c = a.color.usingColorSpace(.sRGB) ?? .red
        color = [c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent]
        lineWidth = a.lineWidth
        text = a.text
        number = a.number
        fontSize = a.fontSize
        alpha = a.alpha
        arrowStyle = a.arrowStyle.rawValue
        arrowReversed = a.arrowReversed
        fillMode = a.fillMode.rawValue
        cornerRadius = a.cornerRadius
        rotation = a.rotation
        textBold = a.textBold
        textItalic = a.textItalic
        textUnderline = a.textUnderline
        textStrikethrough = a.textStrikethrough
        textAlign = a.textAlign.rawValue
        textBackground = a.textBackground
        textOutline = a.textOutline
        let b = a.textBackgroundColor.usingColorSpace(.sRGB) ?? .black
        textBackgroundColor = [b.redComponent, b.greenComponent, b.blueComponent, b.alphaComponent]
        stampEmoji = a.stampEmoji
        loupeZoom = a.loupeZoom
        censorMode = a.censorMode.rawValue
        numberFormat = a.numberFormat.rawValue
        measureUnit = a.measureUnit.rawValue
        spotlightDim = a.spotlightDim
        if let image = a.image,
           let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            imageBase64 = data.base64EncodedString()
        }
    }

    var annotation: CaptureAnnotation {
        var a = CaptureAnnotation(tool: CaptureTool(rawValue: tool) ?? .rectangle,
                                  start: CGPoint(x: start.first ?? 0, y: start.count > 1 ? start[1] : 0),
                                  end: CGPoint(x: end.first ?? 0, y: end.count > 1 ? end[1] : 0),
                                  color: NSColor(srgbRed: color.first ?? 1,
                                                 green: color.count > 1 ? color[1] : 0,
                                                 blue: color.count > 2 ? color[2] : 0,
                                                 alpha: color.count > 3 ? color[3] : 1),
                                  lineWidth: lineWidth)
        a.points = points.compactMap { $0.count > 1 ? CGPoint(x: $0[0], y: $0[1]) : nil }
        a.text = text
        a.number = number
        a.fontSize = fontSize
        a.alpha = alpha
        a.arrowStyle = ArrowStyle(rawValue: arrowStyle) ?? .single
        a.arrowReversed = arrowReversed
        a.fillMode = ShapeFillMode(rawValue: fillMode) ?? .stroke
        a.cornerRadius = cornerRadius
        a.rotation = rotation
        a.textBold = textBold
        a.textItalic = textItalic
        a.textUnderline = textUnderline
        a.textStrikethrough = textStrikethrough
        a.textAlign = TextAlign(rawValue: textAlign) ?? .left
        a.textBackground = textBackground
        a.textOutline = textOutline
        a.textBackgroundColor = NSColor(srgbRed: textBackgroundColor.first ?? 0,
                                        green: textBackgroundColor.count > 1 ? textBackgroundColor[1] : 0,
                                        blue: textBackgroundColor.count > 2 ? textBackgroundColor[2] : 0,
                                        alpha: textBackgroundColor.count > 3 ? textBackgroundColor[3] : 1)
        a.stampEmoji = stampEmoji
        a.loupeZoom = loupeZoom
        a.censorMode = CensorMode(rawValue: censorMode) ?? .pixelate
        a.numberFormat = NumberFormat(rawValue: numberFormat) ?? .arabic
        a.measureUnit = MeasureUnit(rawValue: measureUnit) ?? .pixel
        a.spotlightDim = CGFloat(spotlightDim)
        if let base64 = imageBase64, let data = Data(base64Encoded: base64),
           let rep = NSBitmapImageRep(data: data) {
            a.image = rep.cgImage
        }
        return a
    }
}

struct CaptureEditSession: Codable {
    var savedPath: String
    var baseFile: String
    var annotations: [CaptureAnnotationArchive]
}
