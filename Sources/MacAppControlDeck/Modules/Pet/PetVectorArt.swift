import SwiftUI

/// 纯矢量、无位图依赖的桌宠画布。
struct PetVectorArt: View {
    let skin: PetSkin
    let theme: PetKeyboardTheme
    let detail: PetDetailLevel
    let snapshot: PetSnapshot

    private let designSize = CGSize(width: 240, height: 140)

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
        drawEars(&context)
        drawBody(&context)
        drawHead(&context)
        drawKeyboard(&context)
        drawMouse(&context)
        drawPaws(&context)
        if snapshot.sleeping > 0.2 {
            drawSleepMarks(&context)
        }
    }

    private func drawShadow(_ context: inout GraphicsContext) {
        guard detail.showsShadow else { return }
        let rect = CGRect(x: 54, y: 126, width: 144, height: 12)
        var shadow = context
        shadow.addFilter(.blur(radius: 5))
        shadow.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.16)))
    }

    private func drawTail(_ context: inout GraphicsContext) {
        let wag = snapshot.tailWag * 5
        var path = Path()
        path.move(to: CGPoint(x: 198, y: 96))
        path.addCurve(
            to: CGPoint(x: 222, y: 56 + wag),
            control1: CGPoint(x: 228, y: 92 + wag),
            control2: CGPoint(x: 230, y: 68 + wag)
        )
        path.addCurve(
            to: CGPoint(x: 204, y: 48 + wag),
            control1: CGPoint(x: 216, y: 44 + wag),
            control2: CGPoint(x: 204, y: 50 + wag)
        )
        context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 13)
        context.stroke(path, with: .color(skin.palette.body.color), lineWidth: 7)
    }

    private func drawEars(_ context: inout GraphicsContext) {
        let twitch = snapshot.earTwitch * 2
        if skin.bodyKind == .dog {
            return
        }

        let leftEar = triangle([
            CGPoint(x: 70, y: 40),
            CGPoint(x: 76 + twitch, y: 6),
            CGPoint(x: 102, y: 24)
        ])
        let rightEar = triangle([
            CGPoint(x: 138, y: 24),
            CGPoint(x: 166 - twitch, y: 6),
            CGPoint(x: 172, y: 40)
        ])
        context.fill(leftEar, with: .color(skin.palette.body.color))
        context.fill(rightEar, with: .color(skin.palette.body.color))
        context.stroke(leftEar, with: .color(skin.palette.outline.color), lineWidth: 2.5)
        context.stroke(rightEar, with: .color(skin.palette.outline.color), lineWidth: 2.5)

        let leftInner = triangle([
            CGPoint(x: 78, y: 34),
            CGPoint(x: 81 + twitch, y: 15),
            CGPoint(x: 94, y: 26)
        ])
        let rightInner = triangle([
            CGPoint(x: 146, y: 26),
            CGPoint(x: 159 - twitch, y: 15),
            CGPoint(x: 162, y: 34)
        ])
        context.fill(leftInner, with: .color(skin.palette.innerEar.color))
        context.fill(rightInner, with: .color(skin.palette.innerEar.color))
    }

    private func drawBody(_ context: inout GraphicsContext) {
        let bounce = -snapshot.bodyBounce * 38
        let bodyRect = CGRect(x: 76, y: 44 + bounce, width: 132, height: 84)
        let path = Path(ellipseIn: bodyRect)
        context.fill(path, with: .color(skin.palette.body.color))
        drawPatterns(clippedTo: path, rect: bodyRect, in: &context)
        context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 3)
    }

    private func drawHead(_ context: inout GraphicsContext) {
        let bounce = -snapshot.bodyBounce * 38
        let headRect = CGRect(x: 58, y: 16 + bounce, width: 100, height: 82)
        let head = Path(ellipseIn: headRect)
        context.fill(head, with: .color(skin.palette.body.color))
        drawPatterns(clippedTo: head, rect: headRect, in: &context)
        context.stroke(head, with: .color(skin.palette.outline.color), lineWidth: 3)

        if skin.bodyKind == .dog {
            drawFloppyEars(&context, bounce: bounce)
        }
        drawFace(&context, bounce: bounce)
    }

    private func drawFloppyEars(_ context: inout GraphicsContext, bounce: CGFloat) {
        let twitch = snapshot.earTwitch * 2
        let left = CGRect(x: 42, y: 36 + bounce, width: 30, height: 54)
        let right = CGRect(x: 158 + twitch, y: 38 + bounce, width: 30, height: 56)
        for rect in [left, right] {
            let path = Path(ellipseIn: rect)
            context.fill(path, with: .color(skin.palette.innerEar.color))
            context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 2.5)
        }
        var fold = Path()
        fold.move(to: CGPoint(x: 50, y: 52 + bounce))
        fold.addQuadCurve(to: CGPoint(x: 58, y: 78 + bounce),
                          control: CGPoint(x: 46, y: 66 + bounce))
        context.stroke(fold, with: .color(skin.palette.outline.withAlpha(0.35).color), lineWidth: 1.5)
        fold.move(to: CGPoint(x: 178, y: 54 + bounce))
        fold.addQuadCurve(to: CGPoint(x: 170, y: 80 + bounce),
                          control: CGPoint(x: 184, y: 68 + bounce))
        context.stroke(fold, with: .color(skin.palette.outline.withAlpha(0.35).color), lineWidth: 1.5)
    }

    private func drawFace(_ context: inout GraphicsContext, bounce: CGFloat) {
        let eyeY = 56 + bounce
        let leftEye = CGPoint(x: 94, y: eyeY)
        let rightEye = CGPoint(x: 122, y: eyeY)
        let closed = snapshot.blink > 0.55 || snapshot.sleeping > 0.25

        if closed {
            for center in [leftEye, rightEye] {
                var path = Path()
                path.move(to: CGPoint(x: center.x - 6, y: center.y))
                path.addQuadCurve(
                    to: CGPoint(x: center.x + 6, y: center.y),
                    control: CGPoint(x: center.x, y: center.y + 4)
                )
                context.stroke(path, with: .color(skin.palette.eye.color), lineWidth: 2)
            }
        } else {
            let eyeW: CGFloat = snapshot.surprised > 0.4 ? 13 : 11
            let eyeH: CGFloat = snapshot.surprised > 0.4 ? 16 : 13
            for center in [leftEye, rightEye] {
                let offset = CGPoint(x: snapshot.eyeX * 14, y: -snapshot.eyeY * 10)
                let rect = CGRect(
                    x: center.x - eyeW / 2 + offset.x,
                    y: center.y - eyeH / 2 + offset.y,
                    width: eyeW,
                    height: eyeH
                )
                context.fill(Path(ellipseIn: rect), with: .color(skin.palette.eye.color))
                let eyeLuminance = 0.299 * skin.palette.eye.red
                    + 0.587 * skin.palette.eye.green
                    + 0.114 * skin.palette.eye.blue
                if skin.pattern == .solid, eyeLuminance > 0.55 {
                    let pupil = CGRect(
                        x: rect.midX - 2.2 + offset.x * 0.2,
                        y: rect.midY - 4 + offset.y * 0.2,
                        width: 4.4,
                        height: 8
                    )
                    context.fill(Path(ellipseIn: pupil), with: .color(skin.palette.outline.color))
                }
                let shine = CGRect(x: rect.minX + 2, y: rect.minY + 2, width: 3, height: 3)
                context.fill(Path(ellipseIn: shine), with: .color(Color.white.opacity(0.85)))
            }
        }

        let muzzleY = 66 + bounce
        let muzzleLeft = CGRect(x: 96, y: muzzleY, width: 16, height: 12)
        let muzzleRight = CGRect(x: 112, y: muzzleY, width: 16, height: 12)
        context.fill(Path(ellipseIn: muzzleLeft), with: .color(skin.palette.muzzle.color))
        context.fill(Path(ellipseIn: muzzleRight), with: .color(skin.palette.muzzle.color))

        let noseY = muzzleY + 3
        if skin.bodyKind == .dog {
            context.fill(
                Path(ellipseIn: CGRect(x: 104, y: noseY, width: 16, height: 10)),
                with: .color(skin.palette.outline.color)
            )
        } else {
            let nose = triangle([
                CGPoint(x: 104, y: noseY),
                CGPoint(x: 116, y: noseY),
                CGPoint(x: 110, y: noseY + 6)
            ])
            context.fill(nose, with: .color(skin.palette.outline.color))
        }

        if snapshot.mouthOpen > 0.2 {
            let mouth = Path(ellipseIn: CGRect(x: 104, y: noseY + 6, width: 12, height: 12))
            context.fill(mouth, with: .color(skin.palette.outline.withAlpha(0.85).color))
            context.fill(
                Path(ellipseIn: CGRect(x: 107, y: noseY + 12, width: 6, height: 4)),
                with: .color(skin.palette.innerEar.color)
            )
        } else {
            var mouth = Path()
            mouth.move(to: CGPoint(x: 110, y: noseY + 6))
            mouth.addQuadCurve(
                to: CGPoint(x: 104, y: noseY + 10),
                control: CGPoint(x: 107, y: noseY + 12)
            )
            mouth.move(to: CGPoint(x: 110, y: noseY + 6))
            mouth.addQuadCurve(
                to: CGPoint(x: 116, y: noseY + 10),
                control: CGPoint(x: 113, y: noseY + 12)
            )
            context.stroke(mouth, with: .color(skin.palette.outline.color), lineWidth: 1.6)
        }
        if skin.bodyKind == .dog {
            let tongue = CGRect(x: 107, y: noseY + 13, width: 6, height: 9)
            context.fill(Path(roundedRect: tongue, cornerRadius: 3), with: .color(skin.palette.accent.color))
        }

        let blushAlpha = 0.20 + snapshot.blush * 0.35
        for x in [78.0, 132.0] {
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: 70 + bounce, width: 15, height: 7)),
                with: .color(skin.palette.accent.withAlpha(blushAlpha).color)
            )
        }

        drawWhiskers(&context, muzzleY: muzzleY)
    }

    private func drawWhiskers(_ context: inout GraphicsContext, muzzleY: CGFloat) {
        let count = detail.whiskerCount
        for index in 0..<count {
            let offset = CGFloat(index) * 5
            var left = Path()
            left.move(to: CGPoint(x: 90, y: 69 + offset))
            left.addQuadCurve(
                to: CGPoint(x: 64, y: 62 + offset * 0.7),
                control: CGPoint(x: 78, y: 64 + offset)
            )
            context.stroke(left, with: .color(skin.palette.outline.withAlpha(0.55).color), lineWidth: 1.1)

            var right = Path()
            right.move(to: CGPoint(x: 130, y: 69 + offset))
            right.addQuadCurve(
                to: CGPoint(x: 156, y: 62 + offset * 0.7),
                control: CGPoint(x: 142, y: 64 + offset)
            )
            context.stroke(right, with: .color(skin.palette.outline.withAlpha(0.55).color), lineWidth: 1.1)
        }
    }

    private func drawKeyboard(_ context: inout GraphicsContext) {
        let frame = CGRect(x: 64, y: 102, width: 146, height: 35)
        let framePath = Path(roundedRect: frame, cornerRadius: 8)
        context.fill(framePath, with: .color(theme.body.color))
        context.stroke(framePath, with: .color(skin.palette.outline.color), lineWidth: 2.5)

        let keyWidth: CGFloat = 11.7
        let keyHeight: CGFloat = 5.8
        let gap: CGFloat = 1.6
        let startX: CGFloat = 69.5
        let startY: CGFloat = 106.5
        let rowStrings = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM", " "]
        for row in 0..<4 {
            for column in 0..<10 {
                if row == 3, column > 0 { continue }
                let keyRect: CGRect
                if row == 3 {
                    keyRect = CGRect(x: 72, y: startY + CGFloat(row) * (keyHeight + 2.1),
                                     width: 130, height: keyHeight)
                } else {
                    keyRect = CGRect(x: startX + CGFloat(column) * (keyWidth + gap),
                                     y: startY + CGFloat(row) * (keyHeight + 2.1),
                                     width: keyWidth, height: keyHeight)
                }
                let keyPath = Path(roundedRect: keyRect, cornerRadius: 2)
                context.fill(keyPath, with: .color(theme.keycap.color))
                context.stroke(keyPath, with: .color(theme.stroke.color), lineWidth: 0.8)

                if detail.showsKeyLabels, row < 3 {
                    let labels = Array(rowStrings[row])
                    if column < labels.count {
                        let text = Text(String(labels[column]))
                            .font(.system(size: detail == .full ? 4.4 : 4.0, weight: .medium, design: .rounded))
                            .foregroundColor(skin.palette.outline.color)
                        context.draw(text, at: CGPoint(x: keyRect.midX, y: keyRect.midY), anchor: .center)
                    }
                }
            }
        }

        let front = CGRect(x: 64, y: 134, width: 146, height: 5)
        context.fill(Path(roundedRect: front, cornerRadius: 2.5), with: .color(theme.keycap.color))
        context.stroke(Path(roundedRect: front, cornerRadius: 2.5),
                       with: .color(skin.palette.outline.color), lineWidth: 1.6)

        drawZoneHighlights(&context)
    }

    private func drawZoneHighlights(_ context: inout GraphicsContext) {
        let highlight = theme.highlight.withAlpha(0.38).color
        let zones: [(PetKeyZone, CGRect)] = [
            (.left, CGRect(x: 65, y: 104, width: 62, height: 30)),
            (.center, CGRect(x: 127, y: 104, width: 22, height: 30)),
            (.right, CGRect(x: 149, y: 104, width: 60, height: 30)),
            (.function, CGRect(x: 65, y: 102, width: 144, height: 5))
        ]
        for (zone, rect) in zones where snapshot.activeZones.contains(zone) {
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(highlight))
        }
    }

    private func drawMouse(_ context: inout GraphicsContext) {
        let rect = CGRect(x: 16, y: 101, width: 48, height: 28)
        let path = Path(roundedRect: rect, cornerRadius: 13)
        context.fill(path, with: .color(theme.body.color))
        context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 2.2)

        var divider = Path()
        divider.move(to: CGPoint(x: 40, y: 102))
        divider.addLine(to: CGPoint(x: 40, y: 114))
        context.stroke(divider, with: .color(skin.palette.outline.withAlpha(0.55).color), lineWidth: 1)

        let wheel = CGRect(x: 36.5, y: 104, width: 7, height: 8)
        context.fill(Path(roundedRect: wheel, cornerRadius: 3.5), with: .color(theme.keycap.color))
        context.stroke(Path(roundedRect: wheel, cornerRadius: 3.5),
                       with: .color(skin.palette.outline.color), lineWidth: 1.1)
    }

    private func drawPaws(_ context: inout GraphicsContext) {
        let leftLift = -snapshot.pawLeft * 5
        let rightLift = -snapshot.pawRight * 5
        drawPaw(at: CGPoint(x: 46, y: 99 + leftLift), in: &context)
        drawPaw(at: CGPoint(x: 160, y: 101 + rightLift), in: &context)
    }

    private func drawPaw(at center: CGPoint, in context: inout GraphicsContext) {
        let rect = CGRect(x: center.x - 12, y: center.y - 11, width: 24, height: 22)
        let path = Path(ellipseIn: rect)
        context.fill(path, with: .color(skin.palette.body.color))
        context.stroke(path, with: .color(skin.palette.outline.color), lineWidth: 2.2)
        for index in 0..<3 {
            let x = center.x - 5 + CGFloat(index) * 5
            var toe = Path()
            toe.move(to: CGPoint(x: x, y: center.y + 3))
            toe.addLine(to: CGPoint(x: x, y: center.y + 8))
            context.stroke(toe, with: .color(skin.palette.outline.withAlpha(0.55).color), lineWidth: 1)
        }
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 3, y: center.y + 5, width: 6, height: 4)),
            with: .color(skin.palette.pawPad.color)
        )
    }

    private func drawSleepMarks(_ context: inout GraphicsContext) {
        let color = skin.palette.outline.withAlpha(0.55).color
        let z1 = Text("z").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(color)
        let z2 = Text("z").font(.system(size: 8, weight: .bold, design: .rounded)).foregroundColor(color)
        context.draw(z1, at: CGPoint(x: 164, y: 28), anchor: .center)
        context.draw(z2, at: CGPoint(x: 174, y: 18), anchor: .center)
    }

    private func drawPatterns(clippedTo path: Path, rect: CGRect, in context: inout GraphicsContext) {
        switch skin.pattern {
        case .solid:
            return
        case .tabby:
            var clipped = context
            clipped.clip(to: path)
            for index in 0..<3 {
                let x = rect.minX + 24 + CGFloat(index) * 24
                var stripe = Path()
                stripe.move(to: CGPoint(x: x, y: rect.minY + 6))
                stripe.addQuadCurve(
                    to: CGPoint(x: x + 8, y: rect.minY + 28),
                    control: CGPoint(x: x + 14, y: rect.minY + 15)
                )
                clipped.stroke(stripe, with: .color(skin.palette.stripe.withAlpha(0.75).color), lineWidth: 6)
            }
        case .calico:
            var clipped = context
            clipped.clip(to: path)
            clipped.fill(
                Path(ellipseIn: CGRect(x: rect.minX + 2, y: rect.minY - 10,
                                       width: rect.width * 0.52, height: rect.height * 0.55)),
                with: .color(skin.palette.patchA.color)
            )
            clipped.fill(
                Path(ellipseIn: CGRect(x: rect.midX + 6, y: rect.minY - 2,
                                       width: rect.width * 0.46, height: rect.height * 0.42)),
                with: .color(skin.palette.patchB.color)
            )
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
