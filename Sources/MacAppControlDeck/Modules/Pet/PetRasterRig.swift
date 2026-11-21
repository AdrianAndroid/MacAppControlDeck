import AppKit
import SwiftUI

/// v4 光栅骨架的每帧状态（设计坐标单位：720×960，y 向下）。
struct PetRasterFrame: Equatable {
    /// 瞳孔偏移，单位设计像素，整数化后用于抗抖。
    var eyeX: CGFloat = 0
    var eyeY: CGFloat = 0
    /// 头部旋转角度（度）与垂直微动（设计像素）。
    var headYaw: CGFloat = 0
    var headPitch: CGFloat = 0
    var bob: CGFloat = 0
    var keycaps: [PetKeycap] = []
    /// v5：眨眼（0 开 / 1 闭）、两爪下压进度、鼠标下压、尾摆角、耳抽动角、呼吸相位
    var blink: CGFloat = 0
    var pawL: CGFloat = 0
    var pawR: CGFloat = 0
    var pawMouse: CGFloat = 0
    var tailDeg: CGFloat = 0
    var earDeg: CGFloat = 0
    var breath: CGFloat = 0

    static let idle = PetRasterFrame()
}

/// 分层资产的清单，字段与 manifest.json 一一对应（数值为 2x 像素）。
struct PetRasterManifest: Decodable {
    struct Rect: Decodable {
        let origin: [CGFloat]
        let size: [CGFloat]
    }

    struct Eye: Decodable {
        let center: [CGFloat]
        let box: [CGFloat]
    }

    struct Eyes: Decodable {
        let left: Eye
        let right: Eye
        let pupilRangeX: CGFloat
        let pupilRangeY: CGFloat
    }

    struct Keycap: Decodable {
        let size: [CGFloat]
        let slots: [[CGFloat]]
        let riseY: CGFloat
        let life: CGFloat
    }

    struct HeadRotate: Decodable {
        let yawDeg: CGFloat
        let pitchDeg: CGFloat
    }

    let designSize: [CGFloat]
    let scale: CGFloat
    let scene: Rect
    let head: Rect
    let neck: [CGFloat]
    let eyes: Eyes
    let keycap: Keycap
    let headRotate: HeadRotate

    var designWidth: CGFloat { designSize[0] }
    var designHeight: CGFloat { designSize[1] }

    func designRect(_ rect: Rect) -> CGRect {
        CGRect(
            x: rect.origin[0] / scale,
            y: rect.origin[1] / scale,
            width: rect.size[0] / scale,
            height: rect.size[1] / scale
        )
    }

    func designBox(_ box: [CGFloat], imageSize: CGSize) -> CGRect {
        let width = imageSize.width / scale
        let height = imageSize.height / scale
        return CGRect(x: box[0] / scale, y: box[1] / scale, width: width, height: height)
    }
}

/// 只在第一次渲染时同步加载，失败时整条 v4 渲染链路回退到矢量皮肤。
final class PetRasterAssets {
    static let shared: PetRasterAssets? = PetRasterAssets()

    let manifest: PetRasterManifest
    let scene: Image
    let head: Image
    let eyeL: Image
    let eyeR: Image
    let keycap: Image
    let eyeLSize: CGSize
    let eyeRSize: CGSize

    private init?() {
        guard let root = Self.rootURL(),
              let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(PetRasterManifest.self, from: data),
              let sceneNS = NSImage(contentsOf: root.appendingPathComponent("scene.png")),
              let headNS = NSImage(contentsOf: root.appendingPathComponent("head.png")),
              let eyeLNS = NSImage(contentsOf: root.appendingPathComponent("eyeL.png")),
              let eyeRNS = NSImage(contentsOf: root.appendingPathComponent("eyeR.png")),
              let keycapNS = NSImage(contentsOf: root.appendingPathComponent("keycap.png"))
        else { return nil }

        self.manifest = manifest
        scene = Image(nsImage: sceneNS)
        head = Image(nsImage: headNS)
        eyeL = Image(nsImage: eyeLNS)
        eyeR = Image(nsImage: eyeRNS)
        keycap = Image(nsImage: keycapNS)
        eyeLSize = eyeLNS.size
        eyeRSize = eyeRNS.size
    }

    private static func rootURL() -> URL? {
        let bundleName = "MacAppControlDeck_MacAppControlDeck.bundle"
        var candidates: [URL] = []
        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent(bundleName).appendingPathComponent("v4"))
            candidates.append(resources.appendingPathComponent("v4"))
        }
        candidates.append(Bundle.main.bundleURL
            .appendingPathComponent(bundleName)
            .appendingPathComponent("v4"))
        for url in candidates where FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }
        return nil
    }
}

/// v4 的分层绘制：场景 → 头部（含眼球，整体旋转）→ 键帽。
enum PetRasterRenderer {
    static func draw(_ frame: PetRasterFrame, in context: inout GraphicsContext, size: CGSize) {
        if PetV5Assets.shared != nil {
            PetV5Renderer.draw(frame, in: &context, size: size)
            return
        }
        guard let assets = PetRasterAssets.shared, size.width > 0 else { return }
        let manifest = assets.manifest
        let unit = size.width / manifest.designWidth
        context.scaleBy(x: unit, y: unit)

        context.draw(assets.scene, in: manifest.designRect(manifest.scene))

        let neck = CGPoint(x: manifest.neck[0] / manifest.scale, y: manifest.neck[1] / manifest.scale)
        let headRect = manifest.designRect(manifest.head)
        let eyeLRect = manifest.designBox(manifest.eyes.left.box, imageSize: assets.eyeLSize)
        let eyeRRect = manifest.designBox(manifest.eyes.right.box, imageSize: assets.eyeRSize)
        let eyeOffset = CGPoint(x: frame.eyeX.rounded(), y: frame.eyeY.rounded())

        context.drawLayer { layer in
            layer.translateBy(x: neck.x, y: neck.y + frame.bob + frame.headPitch)
            layer.rotate(by: .degrees(frame.headYaw))
            layer.translateBy(x: -neck.x, y: -neck.y)
            layer.draw(assets.head, in: headRect)
            layer.draw(assets.eyeL, in: eyeLRect.offsetBy(dx: eyeOffset.x, dy: eyeOffset.y))
            layer.draw(assets.eyeR, in: eyeRRect.offsetBy(dx: eyeOffset.x, dy: eyeOffset.y))
        }

        drawKeycaps(frame.keycaps, assets: assets, manifest: manifest, in: &context)
    }

    private static func drawKeycaps(_ keycaps: [PetKeycap],
                                    assets: PetRasterAssets,
                                    manifest: PetRasterManifest,
                                    in context: inout GraphicsContext) {
        guard !keycaps.isEmpty else { return }
        let slots = manifest.keycap.slots
        guard !slots.isEmpty else { return }
        let size = CGSize(width: manifest.keycap.size[0] / manifest.scale,
                          height: manifest.keycap.size[1] / manifest.scale)
        let rise = manifest.keycap.riseY / manifest.scale
        let life = manifest.keycap.life
        let color = Color(red: 0.20, green: 0.18, blue: 0.17)

        for cap in keycaps {
            let slot = slots[cap.slot % slots.count]
            let center = CGPoint(x: slot[0] / manifest.scale, y: slot[1] / manifest.scale)
            let angle = slot.count > 2 ? slot[2] : 0
            let age = cap.progress * life

            var dy: CGFloat = 0
            var scale: CGFloat = 1
            var opacity: CGFloat = 1
            if age < 0.08 {
                let k = max(age, 0) / 0.08
                let ease = 1 - pow(1 - k, 3)
                dy = rise * (1 - ease)
                scale = 0.85 + 0.15 * ease
            } else if age > 0.42 {
                let k = min((age - 0.42) / 0.18, 1)
                dy = -13 * k
                scale = 1 + 0.2 * k
                opacity = 1 - k
            }

            context.drawLayer { layer in
                layer.opacity = opacity
                layer.translateBy(x: center.x, y: center.y + dy)
                layer.rotate(by: .degrees(angle))
                let rect = CGRect(x: -size.width * scale / 2,
                                  y: -size.height * scale / 2,
                                  width: size.width * scale,
                                  height: size.height * scale)
                layer.draw(assets.keycap, in: rect)
                layer.draw(
                    Text(cap.label)
                        .font(.system(size: 17 * scale, weight: .semibold))
                        .foregroundStyle(color),
                    at: CGPoint(x: 0, y: -1)
                )
            }
        }
    }
}

struct PetRasterArt: View {
    let frame: PetRasterFrame

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            PetRasterRenderer.draw(frame, in: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
