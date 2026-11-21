import SwiftUI

/// 参考视频结构的纯矢量桌宠：蹲坐、完整轮廓、目标驱动手脚与键帽。
struct PetVectorArt: View {
    let skin: PetSkin
    let theme: PetKeyboardTheme
    let detail: PetDetailLevel
    let snapshot: PetSnapshot

    private let designSize = PetRigLayout.designSize

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let scale = min(size.width / designSize.width, size.height / designSize.height)
            let offset = CGPoint(
                x: (size.width - designSize.width * scale) / 2,
                y: (size.height - designSize.height * scale) / 2
            )
            context.translateBy(x: offset.x, y: offset.y)
            context.scaleBy(x: scale, y: scale)
            draw(&context)
        }
        .background(Color.clear)
    }

    private func draw(_ context: inout GraphicsContext) {
        drawShadow(&context)
        drawTail(&context)
        drawBody(&context)
        drawHindLegs(&context)
        drawHead(&context)
        drawKeyboard(&context)
        drawMouse(&context)
        drawArms(&context)
        drawKeycaps(&context)
        if skin.id == "midnight-black" {
            drawTailBadge(&context)
        }
        if snapshot.sleeping > 0.35 {
            drawSleepMarks(&context)
        }
    }

    private func drawShadow(_ context: inout GraphicsContext) {
        guard detail.showsShadow else { return }
        var shadow = context
        shadow.addFilter(.blur(radius: 6))
        shadow.fill(
            Path(ellipseIn: CGRect(x: 56, y: 340, width: 168, height: 13)),
            with: .color(Color.black.opacity(0.18))
        )
    }

    private func drawTail(_ context: inout GraphicsContext) {
        let wag = snapshot.tailWag
        let lean = snapshot.bodyLean
        var path = Path()
        path.move(to: CGPoint(x: 176 + lean * 0.4, y: 283))
        path.addCurve(
            to: CGPoint(x: 236, y: 245 + wag * 16),
            control1: CGPoint(x: 210, y: 285),
            control2: CGPoint(x: 238, y: 274 + wag * 8)
        )
        path.addCurve(
            to: CGPoint(x: 243, y: 196 + wag * 24),
            control1: CGPoint(x: 250, y: 224 + wag * 8),
            control2: CGPoint(x: 246, y: 204 + wag * 12)
        )
        path.addCurve(
            to: CGPoint(x: 232, y: 190 + wag * 24),
            control1: CGPoint(x: 240, y: 184 + wag * 20),
            control2: CGPoint(x: 232, y: 183 + wag * 20)
        )
        context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 8.5)
        context.stroke(path, with: .color(skin.palette.body.color), lineWidth: 5.2)
    }

    private func drawHindLegs(_ context: inout GraphicsContext) {
        let lean = snapshot.bodyLean
        let spread = lean * 0.25
        let feet = [
            CGRect(x: 75 - spread, y: 284, width: 52, height: 26),
            CGRect(x: 140 - spread, y: 285, width: 54, height: 27)
        ]
        for rect in feet {
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(skin.palette.body.color))
            context.stroke(path, with: .color(skin.palette.outline.withAlpha(0.55).color), lineWidth: 1.3)
            for index in 0..<2 {
                var toe = Path()
                let x = rect.midX - 6 + CGFloat(index) * 12
                toe.move(to: CGPoint(x: x, y: rect.maxY - 9))
                toe.addLine(to: CGPoint(x: x, y: rect.maxY - 3))
                context.stroke(toe, with: .color(skin.palette.outline.withAlpha(0.35).color), lineWidth: 1)
            }
        }
    }

    private func drawBody(_ context: inout GraphicsContext) {
        let lean = snapshot.bodyLean
        let squash = 1 - snapshot.bodyBounce * 0.7
        let top = 136 + snapshot.bodyBounce * 8
        let bottom = 288 - snapshot.bodyBounce * 3

        var path = Path()
        path.move(to: CGPoint(x: 106 + lean * 0.28, y: top))
        path.addCurve(
            to: CGPoint(x: 90 + lean, y: 236),
            control1: CGPoint(x: 90 + lean * 0.8, y: 174),
            control2: CGPoint(x: 84 + lean, y: 207)
        )
        path.addCurve(
            to: CGPoint(x: 99 + lean, y: bottom),
            control1: CGPoint(x: 84 + lean, y: 262),
            control2: CGPoint(x: 89 + lean, y: 280)
        )
        path.addQuadCurve(
            to: CGPoint(x: 161 + lean, y: bottom),
            control: CGPoint(x: 130 + lean, y: bottom + 4)
        )
        path.addCurve(
            to: CGPoint(x: 170 + lean, y: 236),
            control1: CGPoint(x: 177 + lean, y: 280),
            control2: CGPoint(x: 177 + lean, y: 262)
        )
        path.addCurve(
            to: CGPoint(x: 154 + lean * 0.28, y: top),
            control1: CGPoint(x: 178 + lean, y: 207),
            control2: CGPoint(x: 172 + lean * 0.8, y: 174)
        )
        path.closeSubpath()

        context.fill(path, with: .color(skin.palette.body.color))
        drawPatterns(clippedTo: path, rect: CGRect(x: 88, y: 136, width: 84, height: 154), in: &context)
        context.stroke(path, with: .color(skin.palette.outline.withAlpha(skin.id == "midnight-black" ? 0.45 : 0.9).color), lineWidth: 1.7)
        _ = squash
    }

    private func drawHead(_ context: inout GraphicsContext) {
        var head = context
        let bounce = -snapshot.bodyBounce * 16
        head.translateBy(x: snapshot.bodyLean * 0.32, y: bounce)
        head.translateBy(x: PetRigLayout.neck.x, y: PetRigLayout.neck.y)
        head.rotate(by: .degrees(snapshot.headYaw))
        head.translateBy(x: -PetRigLayout.neck.x, y: -PetRigLayout.neck.y)

        drawEars(&head)
        if skin.bodyKind == .dog {
            drawFloppyEars(&head)
        }
        let headRect = CGRect(x: 80, y: 50, width: 100, height: 88)
        let headPath = Path(ellipseIn: headRect)
        head.fill(headPath, with: .color(skin.palette.body.color))
        drawPatterns(clippedTo: headPath, rect: headRect, in: &head)
        head.stroke(headPath, with: .color(skin.palette.outline.withAlpha(skin.id == "midnight-black" ? 0.45 : 0.9).color), lineWidth: 1.8)
        drawFace(&head)
    }

    private func drawEars(_ context: inout GraphicsContext) {
        if skin.bodyKind == .dog { return }
        let twitch = snapshot.earTwitch * 3
        let leftEar = triangle([
            CGPoint(x: 87, y: 72),
            CGPoint(x: 93 + twitch, y: 36),
            CGPoint(x: 113, y: 60)
        ])
        let rightEar = triangle([
            CGPoint(x: 147, y: 60),
            CGPoint(x: 167 - twitch, y: 36),
            CGPoint(x: 173, y: 72)
        ])
        for path in [leftEar, rightEar] {
            context.fill(path, with: .color(skin.palette.body.color))
            context.stroke(path, with: .color(skin.palette.outline.withAlpha(skin.id == "midnight-black" ? 0.45 : 0.9).color), lineWidth: 1.6)
        }
        let leftInner = triangle([
            CGPoint(x: 93, y: 64),
            CGPoint(x: 96 + twitch, y: 44),
            CGPoint(x: 107, y: 60)
        ])
        let rightInner = triangle([
            CGPoint(x: 153, y: 60),
            CGPoint(x: 164 - twitch, y: 44),
            CGPoint(x: 167, y: 64)
        ])
        for path in [leftInner, rightInner] {
            context.fill(path, with: .color(skin.palette.innerEar.color))
        }
        if skin.id != "midnight-black" {
            context.stroke(leftInner, with: .color(skin.palette.outline.withAlpha(0.28).color), lineWidth: 0.8)
            context.stroke(rightInner, with: .color(skin.palette.outline.withAlpha(0.28).color), lineWidth: 0.8)
        }
    }

    private func drawFloppyEars(_ context: inout GraphicsContext) {
        let twitch = snapshot.earTwitch * 2
        let left = CGRect(x: 63, y: 76 + twitch, width: 27, height: 58)
        let right = CGRect(x: 170 - twitch, y: 76, width: 27, height: 60)
        for rect in [left, right] {
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(skin.palette.innerEar.color))
            context.stroke(path, with: .color(skin.palette.outline.withAlpha(0.8).color), lineWidth: 1.4)
        }
    }

    private func drawFace(_ context: inout GraphicsContext) {
        let eyesClosed = snapshot.blink > 0.55 || snapshot.sleeping > 0.28
        let eyeCenters = [CGPoint(x: 108, y: 96), CGPoint(x: 152, y: 96)]
        let isCat = skin.bodyKind == .cat
        let baseW: CGFloat = isCat ? 34 : 28
        let baseH: CGFloat = isCat ? 42 : 25
        let squint = snapshot.squint
        let eyeH = max(baseH * (1 - squint * 0.38), 7)
        let offset = CGPoint(
            x: min(max(snapshot.eyeX, -1), 1) * (isCat ? 8.5 : 5),
            y: min(max(snapshot.eyeY, -1), 1) * (isCat ? 7.5 : 4)
        )

        if eyesClosed {
            for center in eyeCenters {
                var path = Path()
                path.move(to: CGPoint(x: center.x - baseW * 0.32, y: center.y))
                path.addQuadCurve(
                    to: CGPoint(x: center.x + baseW * 0.32, y: center.y),
                    control: CGPoint(x: center.x, y: center.y + 5)
                )
                context.stroke(path, with: .color(skin.palette.eye.color), lineWidth: 2.2)
            }
        } else {
            for (index, center) in eyeCenters.enumerated() {
                let eyeRect = CGRect(
                    x: center.x - baseW / 2 + offset.x,
                    y: center.y - eyeH / 2 + offset.y + squint * 3,
                    width: baseW,
                    height: eyeH
                )
                let eyePath = Path(ellipseIn: eyeRect)
                if isCat {
                    context.fill(eyePath, with: .color(skin.palette.eye.color))
                    let luminance = 0.299 * skin.palette.eye.red
                        + 0.587 * skin.palette.eye.green
                        + 0.114 * skin.palette.eye.blue
                    if luminance > 0.22 {
                        let pupilRect = CGRect(
                            x: eyeRect.midX - 3.8 + offset.x * 0.25,
                            y: eyeRect.midY - eyeH * 0.34 + offset.y * 0.15,
                            width: 7.6,
                            height: eyeH * 0.68
                        )
                        context.fill(Path(ellipseIn: pupilRect), with: .color(skin.palette.outline.color))
                    }
                } else {
                    context.fill(eyePath, with: .color(Color.white))
                    context.stroke(eyePath, with: .color(skin.palette.outline.withAlpha(0.6).color), lineWidth: 0.8)
                    let pupilRect = CGRect(
                        x: eyeRect.midX - 5 + offset.x * 0.35,
                        y: eyeRect.midY - 6 + offset.y * 0.2,
                        width: 10,
                        height: 12
                    )
                    context.fill(Path(ellipseIn: pupilRect), with: .color(PetColor(hex: "2B2018").color))
                }
                let shine = CGRect(
                    x: eyeRect.minX + (index == 0 ? 5 : 4),
                    y: eyeRect.minY + 5,
                    width: isCat ? 6 : 4,
                    height: isCat ? 6 : 4
                )
                context.fill(Path(ellipseIn: shine), with: .color(Color.white.opacity(0.85)))
            }
        }

        if skin.bodyKind == .dog {
            let muzzle = Path(ellipseIn: CGRect(x: 111, y: 113, width: 38, height: 24))
            context.fill(muzzle, with: .color(skin.palette.muzzle.color))
            context.stroke(muzzle, with: .color(skin.palette.outline.withAlpha(0.7).color), lineWidth: 1)
            context.fill(
                Path(ellipseIn: CGRect(x: 124, y: 112, width: 12, height: 8)),
                with: .color(skin.palette.outline.color)
            )
            if true {
                let tongue = CGRect(x: 127, y: 124, width: 8, height: 12)
                context.fill(Path(roundedRect: tongue, cornerRadius: 4), with: .color(skin.palette.accent.color))
            }
        }

        let count = detail.whiskerCount
        for index in 0..<count {
            let offsetY = CGFloat(index) * 5.2
            var left = Path()
            left.move(to: CGPoint(x: 96, y: 112 + offsetY))
            left.addQuadCurve(
                to: CGPoint(x: 66, y: 107 + offsetY * 0.85),
                control: CGPoint(x: 78, y: 109 + offsetY)
            )
            context.stroke(left, with: .color(skin.palette.outline.withAlpha(0.5).color), lineWidth: 0.9)

            var right = Path()
            right.move(to: CGPoint(x: 164, y: 112 + offsetY))
            right.addQuadCurve(
                to: CGPoint(x: 194, y: 107 + offsetY * 0.85),
                control: CGPoint(x: 182, y: 109 + offsetY)
            )
            context.stroke(right, with: .color(skin.palette.outline.withAlpha(0.5).color), lineWidth: 0.9)
        }

        if snapshot.blush > 0.05, skin.bodyKind == .cat, skin.id != "midnight-black" {
            for x in [83.0, 157.0] {
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: 116, width: 18, height: 7)),
                    with: .color(skin.palette.accent.withAlpha(0.15 + snapshot.blush * 0.3).color)
                )
            }
        }
    }

    private func drawMouse(_ context: inout GraphicsContext) {
        let shift = CGPoint(
            x: min(max(snapshot.mouseShift.x, -4), 4),
            y: min(max(snapshot.mouseShift.y, -2), 2)
        )
        let center = CGPoint(
            x: PetRigLayout.mouseCenter.x + shift.x,
            y: PetRigLayout.mouseCenter.y + shift.y
        )
        let rect = CGRect(
            x: center.x - PetRigLayout.mouseSize.width / 2,
            y: center.y - PetRigLayout.mouseSize.height / 2,
            width: PetRigLayout.mouseSize.width,
            height: PetRigLayout.mouseSize.height
        )
        let path = Path(roundedRect: rect, cornerRadius: 13)
        context.fill(path, with: .color(PetColor(hex: "FAF7EF").color))
        context.stroke(path, with: .color(skin.palette.outline.withAlpha(0.8).color), lineWidth: 1.5)

        var divider = Path()
        divider.move(to: CGPoint(x: rect.midX, y: rect.minY + 2))
        divider.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 11))
        context.stroke(divider, with: .color(skin.palette.outline.withAlpha(0.35).color), lineWidth: 0.8)

        let wheel = CGRect(x: rect.midX - 3, y: rect.minY + 3, width: 6, height: 7)
        context.fill(Path(roundedRect: wheel, cornerRadius: 3), with: .color(theme.keycap.color))
        context.stroke(Path(roundedRect: wheel, cornerRadius: 3),
                       with: .color(skin.palette.outline.withAlpha(0.5).color), lineWidth: 0.8)
    }

    private func drawKeyboard(_ context: inout GraphicsContext) {
        let frame = CGRect(
            x: PetKeyboardLayout.origin.x - 4,
            y: PetKeyboardLayout.origin.y - 3,
            width: PetKeyboardLayout.width + 8,
            height: PetKeyboardLayout.height + 6
        )
        var keyboard = context
        keyboard.translateBy(x: frame.midX, y: frame.midY)
        keyboard.rotate(by: .degrees(-0.9))
        keyboard.translateBy(x: -frame.midX, y: -frame.midY)

        let extrusion = frame.offsetBy(dx: 0, dy: 4)
        keyboard.fill(
            Path(roundedRect: extrusion, cornerRadius: 7),
            with: .color(theme.stroke.color)
        )
        let path = Path(roundedRect: frame, cornerRadius: 7)
        keyboard.fill(path, with: .color(theme.body.color))
        keyboard.stroke(path, with: .color(skin.palette.outline.withAlpha(0.85).color), lineWidth: 1.8)

        for row in 0..<PetKeyboardLayout.rowCount {
            for column in 0..<PetKeyboardLayout.columnCount {
                let keyFrame = PetKeyboardLayout.visualFrame(row: row, column: column)
                let keyPath = Path(roundedRect: keyFrame, cornerRadius: 1.4)
                let isOrange = (row == 1 && column == 0) || (row == 3 && column == 19)
                let fill = isOrange ? PetColor(hex: "F2A33A").color : theme.keycap.color
                keyboard.fill(keyPath, with: .color(fill))
                keyboard.stroke(
                    keyPath,
                    with: .color(skin.palette.outline.withAlpha(0.32).color),
                    lineWidth: 0.4
                )
            }
        }

        for press in snapshot.pressedKeys {
            guard let key = PetKeyMap.key(for: press.code) else { continue }
            var keyFrame = PetKeyboardLayout.frame(row: key.row, column: key.column)
            keyFrame.origin.y += press.depth * 1.6
            keyFrame.size.height -= press.depth * 0.7
            let keyPath = Path(roundedRect: keyFrame, cornerRadius: 1.4)
            keyboard.fill(keyPath, with: .color(Color.black.opacity(0.16)))
            keyboard.stroke(keyPath, with: .color(skin.palette.outline.withAlpha(0.5).color), lineWidth: 0.6)
        }

        let front = CGRect(
            x: frame.minX + 2,
            y: frame.maxY - 4,
            width: frame.width - 4,
            height: 3.5
        )
        keyboard.fill(Path(roundedRect: front, cornerRadius: 1.5),
                      with: .color(theme.keycap.withAlpha(0.95).color))
    }

    private func drawArms(_ context: inout GraphicsContext) {
        let leftBend: CGFloat = 1
        let rightBend: CGFloat = -1
        let leftElbow = PetRigLayout.elbow(
            shoulder: PetRigLayout.leftShoulder,
            paw: snapshot.leftPawPoint,
            bend: leftBend
        )
        let rightElbow = PetRigLayout.elbow(
            shoulder: PetRigLayout.rightShoulder,
            paw: snapshot.rightPawPoint,
            bend: rightBend
        )
        drawArm(
            shoulder: PetRigLayout.leftShoulder,
            elbow: leftElbow,
            paw: snapshot.leftPawPoint,
            side: .left,
            in: &context
        )
        drawArm(
            shoulder: PetRigLayout.rightShoulder,
            elbow: rightElbow,
            paw: snapshot.rightPawPoint,
            side: .right,
            in: &context
        )
    }

    private func drawArm(
        shoulder: PetPoint,
        elbow: PetPoint,
        paw: PetPoint,
        side: PetKeyZone,
        in context: inout GraphicsContext
    ) {
        let mid = CGPoint(
            x: (elbow.x + paw.x) / 2 + (side == .left ? -2.5 : 2.5),
            y: (elbow.y + paw.y) / 2
        )
        var path = Path()
        path.move(to: shoulder.cgPoint)
        path.addQuadCurve(
            to: elbow.cgPoint,
            control: CGPoint(
                x: (shoulder.x + elbow.x) / 2 + (side == .left ? -3 : 3),
                y: (shoulder.y + elbow.y) / 2
            )
        )
        path.addQuadCurve(
            to: paw.cgPoint,
            control: mid
        )
        context.stroke(path, with: .color(skin.palette.outline.withAlpha(0.4).color), lineWidth: 8.2)
        context.stroke(path, with: .color(skin.palette.body.color), lineWidth: 6.0)
        context.fill(
            Path(ellipseIn: CGRect(x: shoulder.x - 6, y: shoulder.y - 6, width: 12, height: 12)),
            with: .color(skin.palette.body.color)
        )

        let press = side == .left ? snapshot.pawLeft : snapshot.pawRight
        let pawRect = CGRect(
            x: paw.x - 11,
            y: paw.y - 10 + press * 1.2,
            width: 22,
            height: 20
        )
        let pawPath = Path(ellipseIn: pawRect)
        context.fill(pawPath, with: .color(skin.palette.pawMitt.color))
        context.stroke(pawPath, with: .color(skin.palette.outline.withAlpha(0.65).color), lineWidth: 1.1)
        for index in 0..<2 {
            var toe = Path()
            let x = pawRect.midX - 3.5 + CGFloat(index) * 7
            toe.move(to: CGPoint(x: x, y: pawRect.maxY - 6))
            toe.addLine(to: CGPoint(x: x, y: pawRect.maxY - 2))
            context.stroke(toe, with: .color(skin.palette.outline.withAlpha(0.35).color), lineWidth: 0.8)
        }
    }

    private func drawKeycaps(_ context: inout GraphicsContext) {
        let slots: [(CGFloat, CGFloat, CGFloat)] = [
            (94, 198, -0.05), (126, 191, 0.04), (158, 197, -0.02),
            (190, 203, 0.05), (110, 225, 0.02), (146, 228, -0.04)
        ]
        for keycap in snapshot.keycaps {
            let slot = slots[min(max(keycap.slot, 0), slots.count - 1)]
            let progress = keycap.progress
            let pop = progress < 0.12
                ? 0.7 + progress / 0.12 * 0.4
                : (progress < 0.2 ? 1.1 - (progress - 0.12) / 0.08 * 0.1 : 1.0)
            let alpha: CGFloat = progress > 0.7 ? max(0.01, (1 - progress) / 0.3) : 1
            let width: CGFloat = keycap.label.count > 2 ? 36 : 31
            let rect = CGRect(x: slot.0 - width / 2, y: slot.1 - 11, width: width, height: 22)

            var badge = context
            badge.translateBy(x: rect.midX, y: rect.midY)
            badge.rotate(by: .radians(Double(slot.2)))
            badge.scaleBy(x: pop, y: pop)
            badge.translateBy(x: -rect.midX, y: -rect.midY)
            badge.opacity = alpha

            let shadow = CGRect(x: rect.minX + 1.5, y: rect.minY + 2, width: rect.width, height: rect.height)
            badge.fill(Path(roundedRect: shadow, cornerRadius: 6), with: .color(Color.black.opacity(0.14)))
            let path = Path(roundedRect: rect, cornerRadius: 6)
            badge.fill(path, with: .color(PetColor(hex: "FAF7EF").color))
            badge.stroke(path, with: .color(skin.palette.outline.withAlpha(0.78).color), lineWidth: 1.2)

            let fontSize: CGFloat = keycap.label.count > 2 ? 7.5 : 11.5
            if let glyph = Self.keycapGlyph(label: keycap.label, fontSize: fontSize, color: skin.palette.outline) {
                let glyphRect = CGRect(x: rect.midX - 20, y: rect.midY - 11, width: 40, height: 22)
                badge.draw(glyph, in: glyphRect)
            }
        }
    }

    @MainActor private static var glyphCache: [String: Image] = [:]

    @MainActor
    private static func keycapGlyph(label: String, fontSize: CGFloat, color: PetColor) -> Image? {
        let key = "\(label)|\(fontSize)|\(color.red)|\(color.green)|\(color.blue)|\(color.alpha)"
        if let cached = glyphCache[key] { return cached }
        let size = NSSize(width: 40, height: 22)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor(color.color)
        ]
        let image = NSImage(size: size, flipped: false) { rect in
            let textSize = (label as NSString).size(withAttributes: attributes)
            (label as NSString).draw(
                at: NSPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2),
                withAttributes: attributes
            )
            return true
        }
        let swiftImage = Image(nsImage: image)
        if glyphCache.count > 80 { glyphCache.removeAll(keepingCapacity: true) }
        glyphCache[key] = swiftImage
        return swiftImage
    }

    private func drawTailBadge(_ context: inout GraphicsContext) {
        let rect = CGRect(x: 214, y: 272, width: 28, height: 18)
        let path = Path(roundedRect: rect, cornerRadius: 5)
        context.fill(path, with: .color(PetColor(hex: "FAF7EF").color))
        context.stroke(path, with: .color(skin.palette.outline.withAlpha(0.8).color), lineWidth: 1)
        context.draw(
            Text("S").font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(skin.palette.outline.color),
            at: CGPoint(x: rect.midX, y: rect.midY),
            anchor: .center
        )
    }

    private func drawSleepMarks(_ context: inout GraphicsContext) {
        let color = skin.palette.outline.withAlpha(0.55).color
        context.draw(
            Text("z").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(color),
            at: CGPoint(x: 184, y: 70), anchor: .center
        )
        context.draw(
            Text("z").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundColor(color),
            at: CGPoint(x: 196, y: 58), anchor: .center
        )
    }

    private func drawPatterns(clippedTo path: Path, rect: CGRect, in context: inout GraphicsContext) {
        switch skin.pattern {
        case .solid:
            return
        case .tabby:
            var clipped = context
            clipped.clip(to: path)
            for index in 0..<4 {
                let x = rect.minX + 16 + CGFloat(index) * 22
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: rect.minY + 4))
                stripe.addQuadCurve(
                    to: CGPoint(x: x + 7, y: rect.minY + 30),
                    control: CGPoint(x: x + 12, y: rect.minY + 16)
                )
                clipped.stroke(stripe, with: .color(skin.palette.stripe.withAlpha(0.75).color), lineWidth: 5)
            }
        case .calico:
            var clipped = context
            clipped.clip(to: path)
            let isHead = rect.height < 100
            if isHead {
                clipped.fill(
                    Path(ellipseIn: CGRect(x: rect.minX + 1, y: rect.minY - 4,
                                           width: rect.width * 0.42, height: rect.height * 0.30)),
                    with: .color(skin.palette.patchA.color)
                )
                clipped.fill(
                    Path(ellipseIn: CGRect(x: rect.maxX - rect.width * 0.46, y: rect.minY - 7,
                                           width: rect.width * 0.44, height: rect.height * 0.28)),
                    with: .color(skin.palette.patchB.color)
                )
            } else {
                clipped.fill(
                    Path(ellipseIn: CGRect(x: rect.minX + 2, y: rect.minY - 8,
                                           width: rect.width * 0.55, height: rect.height * 0.48)),
                    with: .color(skin.palette.patchA.color)
                )
                clipped.fill(
                    Path(ellipseIn: CGRect(x: rect.midX + 4, y: rect.minY - 2,
                                           width: rect.width * 0.44, height: rect.height * 0.38)),
                    with: .color(skin.palette.patchB.color)
                )
            }
        }
    }

    private func triangle(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count == 3 else { return path }
        path.move(to: points[0])
        path.addLine(to: points[1])
        path.addLine(to: points[2])
        path.closeSubpath()
        return path
    }
}
