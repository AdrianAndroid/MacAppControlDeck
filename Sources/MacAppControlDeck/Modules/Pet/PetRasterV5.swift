import AppKit
import SwiftUI

/// v5 分层骨架：去桌面、共视双眼（虹膜固定 / 瞳孔偏移）、眨眼、局部爪子、尾耳微动。
struct PetV5Manifest: Decodable {
    struct Layer: Decodable {
        let box: [CGFloat]
        let z: Int
        let pivot: [CGFloat]?
        let swingDeg: CGFloat?
        let pressY: CGFloat?
    }
    struct Eye: Decodable {
        let box: [CGFloat]
        let size: [CGFloat]
        let center: [CGFloat]
        let pupil: [CGFloat]
        let radius: CGFloat
    }
    struct Eyes: Decodable {
        let left: Eye
        let right: Eye
        let pupilRange: [CGFloat]
    }
    struct Keycaps: Decodable {
        let riseY: CGFloat
        let life: CGFloat
        let slots: Int
    }
    let designSize: [CGFloat]
    let scale: CGFloat
    let layers: [String: Layer]
    let eyes: Eyes
    let keycaps: Keycaps
    let keyboardBox: [CGFloat]?

    var designWidth: CGFloat { designSize[0] }
    var designHeight: CGFloat { designSize[1] }
    func fullRect() -> CGRect { CGRect(x: 0, y: 0, width: designWidth, height: designHeight) }
    func point(_ arr: [CGFloat]) -> CGPoint { CGPoint(x: arr[0] / scale, y: arr[1] / scale) }
}

final class PetV5Assets {
    static let shared: PetV5Assets? = PetV5Assets()

    let manifest: PetV5Manifest
    private(set) var images: [String: Image] = [:]
    private(set) var irisL = Image(systemName: "circle")
    private(set) var irisR = Image(systemName: "circle")
    private(set) var pupilL = Image(systemName: "circle")
    private(set) var pupilR = Image(systemName: "circle")
    private(set) var keycap = Image(systemName: "circle")

    private init?() {
        guard let root = Self.locate() else { return nil }
        guard let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(PetV5Manifest.self, from: data) else { return nil }
        self.manifest = manifest
        let required = ["shadow", "keyboard", "mouse", "body", "neck", "tail", "head",
                        "earL", "earR", "pawL", "pawR", "patchL", "patchR", "patchTail",
                        "irisL", "irisR", "pupilL", "pupilR", "keycap"]
        for name in required {
            guard let ns = NSImage(contentsOf: root.appendingPathComponent("\(name).png")) else { return nil }
            let img = Image(nsImage: ns)
            if name.hasPrefix("iris") || name.hasPrefix("pupil") || name == "keycap" {
                switch name {
                case "irisL": irisL = img
                case "irisR": irisR = img
                case "pupilL": pupilL = img
                case "pupilR": pupilR = img
                case "keycap": keycap = img
                default: break
                }
            } else {
                images[name] = img
            }
        }
    }

    private static func locate() -> URL? {
        var candidates: [URL] = []
        // SwiftPM 资源包（测试与开发期也能直接命中）
        if let res = Bundle.module.resourceURL {
            candidates.append(res.appendingPathComponent("v5"))
        }
        let bundleName = "MacAppControlDeck_MacAppControlDeck.bundle"
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent(bundleName).appendingPathComponent("v5"))
            candidates.append(res.appendingPathComponent("v5"))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
            .appendingPathComponent(bundleName).appendingPathComponent("v5"))
        for url in candidates where FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }
        return nil
    }
}

enum PetV5Renderer {
    static func draw(_ frame: PetRasterFrame, in context: inout GraphicsContext, size: CGSize) {
        guard let assets = PetV5Assets.shared, size.width > 0 else { return }
        let m = assets.manifest
        let unit = size.width / m.designWidth
        context.scaleBy(x: unit, y: unit)
        let full = m.fullRect()
        let breath = frame.breath
        let sink = breath * 1.2                     // 呼吸起伏（设计像素）

        func draw(_ name: String) {
            if let img = assets.images[name] { context.draw(img, in: full) }
        }

        draw("shadow")

        // 键鼠在猫之前画：猫爪/尾巴盖住它们（不再靠 alpha 挖洞）
        draw("keyboard")
        if let mouse = assets.images["mouse"] {
            context.drawLayer { layer in
                layer.translateBy(x: 0, y: frame.pawMouse * 2)
                layer.draw(mouse, in: full)
            }
        }

        // 身体（呼吸：绕底边轻微缩放 + 上移）
        context.drawLayer { layer in
            layer.translateBy(x: 0, y: 0.9)
            layer.scaleBy(x: 1, y: 1 + 0.008 * breath)
            layer.translateBy(x: 0, y: -0.9)
            layer.translateBy(x: 0, y: -sink / 2)
            layer.draw(assets.images["body"] ?? Image(systemName: "circle"), in: full)
        }

        // 颈部补片：头部单独摆动时露出的缝隙用同一块原图像素补上（画在头之下）
        draw("neck")

        // 尾巴（绕尾根摆动）
        if let tail = assets.images["tail"], let pivotArr = m.layers["tail"]?.pivot {
            let pivot = m.point(pivotArr)
            let deg = frame.tailDeg
            context.drawLayer { layer in
                layer.translateBy(x: pivot.x, y: pivot.y)
                layer.rotate(by: .degrees(deg))
                layer.translateBy(x: -pivot.x, y: -pivot.y)
                layer.draw(tail, in: full)
            }
        }

        // 爪子：起身（patch 盖住原爪）→ 爪精灵下压
        for (name, patch, progress) in [("pawL", "patchL", frame.pawL), ("pawR", "patchR", frame.pawR)] {
            guard let paw = assets.images[name], progress > 0.01 else { continue }
            context.drawLayer { layer in
                layer.opacity = min(1, Double(progress) * 1.6)
                layer.draw(assets.images[patch] ?? Image(systemName: "circle"), in: full)
                layer.translateBy(x: 0, y: 3 * progress)
                layer.scaleBy(x: 1 + 0.02 * progress, y: 1 - 0.05 * progress)
                layer.translateBy(x: 0, y: -1 * progress)
                layer.opacity = 1
                layer.draw(paw, in: full)
            }
        }

        // 键帽：从真实键位上升起，画在爪子之上、头之下
        drawKeycaps(frame.keycaps, assets: assets, m: m, in: &context)

        // 头 + 耳 + 两眼（同一旋转坐标系，保证眼球不相对眼眶滑动）
        let neck = m.layers["head"]?.pivot.map { m.point($0) } ?? CGPoint(x: 225, y: 481)
        let yaw = frame.headYaw, pitch = frame.headPitch + frame.bob
        context.drawLayer { layer in
            layer.translateBy(x: neck.x, y: neck.y + pitch)
            layer.rotate(by: .degrees(yaw))
            layer.translateBy(x: -neck.x, y: -neck.y)
            layer.draw(assets.images["head"] ?? Image(systemName: "circle"), in: full)

            // 耳（轻微抽动，绕各自耳根）
            for (earName, sign) in [("earL", CGFloat(-1)), ("earR", CGFloat(1))] {
                guard let img = assets.images[earName], let p = m.layers[earName]?.pivot else { continue }
                let pivot = m.point(p)
                layer.drawLayer { sub in
                    sub.translateBy(x: pivot.x, y: pivot.y)
                    sub.rotate(by: .degrees(frame.earDeg * sign))
                    sub.translateBy(x: -pivot.x, y: -pivot.y)
                    sub.draw(img, in: full)
                }
            }

            // 虹膜（固定）+ 瞳孔（共视偏移）+ 眼睑
            drawEye(layer: &layer, assets: assets, m: m, eye: m.eyes.left, iris: assets.irisL,
                    pupil: assets.pupilL, frame: frame)
            drawEye(layer: &layer, assets: assets, m: m, eye: m.eyes.right, iris: assets.irisR,
                    pupil: assets.pupilR, frame: frame)
        }

    }

    private static func drawEye(layer: inout GraphicsContext,
                                assets: PetV5Assets,
                                m: PetV5Manifest,
                                eye: PetV5Manifest.Eye,
                                iris: Image,
                                pupil: Image,
                                frame: PetRasterFrame) {
        let rect = CGRect(x: eye.box[0] / m.scale, y: eye.box[1] / m.scale,
                          width: eye.size[0] / m.scale, height: eye.size[1] / m.scale)
        layer.draw(iris, in: rect)

        // 共视偏移：虹膜不动，只动瞳孔；上限约为眼半径的 45%
        let maxD = eye.radius / m.scale * 0.45
        let dx = max(-maxD, min(maxD, frame.eyeX * 0.55))
        let dy = max(-maxD, min(maxD, frame.eyeY * 0.45))
        layer.draw(pupil, in: rect.offsetBy(dx: dx.rounded(), dy: dy.rounded()))

        // 眼睑：在眼框内自上而下填充毛色，双眼同相位
        guard frame.blink > 0.02 else { return }
        let center = CGPoint(x: eye.center[0] / m.scale, y: eye.center[1] / m.scale)
        let r = CGSize(width: eye.size[0] / m.scale * 0.46, height: eye.size[1] / m.scale * 0.5)
        let ellipse = Path(ellipseIn: CGRect(x: center.x - r.width, y: center.y - r.height,
                                              width: r.width * 2, height: r.height * 2))
        layer.drawLayer { sub in
            sub.clip(to: ellipse)
            let h = r.height * 2 * frame.blink
            let rect = CGRect(x: center.x - r.width, y: center.y - r.height,
                              width: r.width * 2, height: h + 1)
            sub.fill(Path(rect), with: .color(Color(red: 0.10, green: 0.095, blue: 0.09)))
            // 眼睑下缘一道淡光，避免"一块黑幕"
            let rim = CGRect(x: center.x - r.width, y: rect.maxY - 1.5, width: r.width * 2, height: 1.5)
            sub.fill(Path(rim), with: .color(Color(red: 0.22, green: 0.20, blue: 0.19).opacity(0.55)))
        }
    }

    private static func drawKeycaps(_ keycaps: [PetKeycap],
                                    assets: PetV5Assets,
                                    m: PetV5Manifest,
                                    in context: inout GraphicsContext) {
        guard !keycaps.isEmpty else { return }
        let capSize = CGSize(width: 33, height: 27)         // point（≈真实键帽尺寸）
        // 真实键位 → 键盘画布坐标：column 0..13 横向铺满，row 0..3 纵向三档
        let kbRaw = m.keyboardBox ?? [70, 1400, 1010, 1600]
        // manifest 里是 2x 设计像素，绘制坐标系是 point（设计宽度 720）
        let kb = kbRaw.map { $0 / m.scale }
        let kbW = kb[2] - kb[0]
        for cap in keycaps {
            let p = min(max(cap.progress, 0), 1)
            let lift: CGFloat
            let opacity: CGFloat
            if p < 0.15 {
                lift = -10 * (p / 0.15); opacity = p / 0.15
            } else if p < 0.7 {
                lift = -10; opacity = 1
            } else {
                let q = (p - 0.7) / 0.3
                lift = -10 - 26 * q; opacity = 1 - q
            }
            let colFrac = CGFloat(min(max(cap.column, 0), 13)) / 13.0
            let rowFrac = CGFloat(min(max(cap.row, 0), 3)) / 3.0
            let centerX = kb[0] + kbW * (0.06 + colFrac * 0.86)
            let baseY = kb[1] + 26 + rowFrac * 34
            let originX = centerX - capSize.width / 2
            let originY = baseY - capSize.height / 2 + lift
            var layer = context
            layer.opacity = Double(opacity)
            layer.drawLayer { sub in
                sub.translateBy(x: originX + capSize.width / 2, y: originY + capSize.height / 2)
                sub.rotate(by: .degrees(CGFloat(cap.slot % 2 == 0 ? -3 : 3)))
                sub.translateBy(x: -(originX + capSize.width / 2), y: -(originY + capSize.height / 2))
                sub.draw(assets.keycap, in: CGRect(origin: CGPoint(x: originX, y: originY), size: capSize))
                sub.draw(Text(cap.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.17)),
                         at: CGPoint(x: originX + capSize.width / 2, y: originY + capSize.height / 2))
            }
        }
    }
}
