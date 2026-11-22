import AppKit
import SwiftUI

/// v6 全身骨架：躯干/手臂/颈头/双耳/双尾段/双眼/键鼠，全部按「设计 pt」定位，
/// 振幅以屏上 pt 反推（设计 pt = 屏 pt / unit），保证 288pt 窗口下动作看得见。
struct PetV6Manifest: Decodable {
    struct Layer: Decodable {
        let box: [CGFloat]
        let pivot: [CGFloat]?
    }
    struct Rig: Decodable {
        let neck: [CGFloat]
        let hip: [CGFloat]
        let shoulderL: [CGFloat]
        let shoulderR: [CGFloat]
        let pawL: [CGFloat]
        let pawR: [CGFloat]
        let tailRoot: [CGFloat]
        let tailMid: [CGFloat]
        let earLBase: [CGFloat]
        let earRBase: [CGFloat]
        let eyeL: [CGFloat]
        let eyeR: [CGFloat]
        let eyeRadius: [CGFloat]
        let gazeRange: [CGFloat]
        let pupilRange: [CGFloat]
        let headYaw: CGFloat
        let headPitch: CGFloat
        let torsoLean: CGFloat
        let torsoBreathe: CGFloat
        let tailSwing: CGFloat
        let earTwitch: CGFloat
        let armSwing: CGFloat
        let keycapRise: CGFloat
        let keycapLife: CGFloat
    }
    struct Grid: Decodable {
        let box: [CGFloat]
        let backRowY: CGFloat
        let rowGap: CGFloat
        let colStartX: CGFloat
        let colGap: CGFloat
    }

    let designSize: [CGFloat]
    let scale: CGFloat
    let canvas: [CGFloat]
    let order: [String]
    let layers: [String: Layer]
    let rig: Rig
    let keyboardGrid: Grid

    var designWidth: CGFloat { designSize[0] }
    var designHeight: CGFloat { designSize[1] }

    func pt(_ v: CGFloat) -> CGFloat { v / scale }

    func rect(for name: String, imageSize: CGSize) -> CGRect {
        guard let layer = layers[name] else { return .zero }
        return CGRect(x: pt(layer.box[0]), y: pt(layer.box[1]),
                      width: pt(imageSize.width), height: pt(imageSize.height))
    }

    func pivot(for name: String) -> CGPoint? {
        guard let layer = layers[name], let p = layer.pivot else { return nil }
        return CGPoint(x: pt(layer.box[0]) + pt(p[0]), y: pt(layer.box[1]) + pt(p[1]))
    }
}

final class PetV6Assets {
    static let shared: PetV6Assets? = PetV6Assets()

    let manifest: PetV6Manifest
    private(set) var images: [String: Image] = [:]
    private(set) var sizes: [String: CGSize] = [:]

    private init?() {
        guard let root = Self.locate() else { return nil }
        guard let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
              let manifest = try? JSONDecoder().decode(PetV6Manifest.self, from: data) else { return nil }
        self.manifest = manifest
        let required = ["shadow", "keyboard", "keycap", "mouse", "torso", "neck", "head",
                        "earL", "earR", "armL", "armR", "tail1", "tail2",
                        "iris_l", "iris_r", "pupil_l", "pupil_r"]
        for name in required {
            guard let ns = NSImage(contentsOf: root.appendingPathComponent("\(name).png")) else { return nil }
            images[name] = Image(nsImage: ns)
            sizes[name] = ns.size
        }
    }

    private static func locate() -> URL? {
        var candidates: [URL] = []
        if let res = Bundle.module.resourceURL {
            candidates.append(res.appendingPathComponent("v6"))
        }
        let bundleName = "MacAppControlDeck_MacAppControlDeck.bundle"
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent(bundleName).appendingPathComponent("v6"))
            candidates.append(res.appendingPathComponent("v6"))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
            .appendingPathComponent(bundleName).appendingPathComponent("v6"))
        for url in candidates where FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            return url
        }
        return nil
    }
}

/// v6 渲染：一个「躯干坐标系」包住尾巴/手臂/颈头/耳/眼，所有局部动作都叠在躯干之上，
/// 于是身子一动，头、手、尾会跟着一起动 —— 这正是旧版局部 rig 缺的「整体协调」。
enum PetV6Renderer {
    static func draw(_ frame: PetRasterFrame, in context: inout GraphicsContext, size: CGSize) {
        guard let assets = PetV6Assets.shared, size.width > 0 else { return }
        let m = assets.manifest
        let unit = size.width / m.designWidth
        context.scaleBy(x: unit, y: unit)
        let rig = m.rig

        func image(_ name: String, into ctx: inout GraphicsContext) {
            guard let img = assets.images[name], let sz = assets.sizes[name] else { return }
            ctx.draw(img, in: m.rect(for: name, imageSize: sz))
        }

        func point(_ arr: [CGFloat]) -> CGPoint { CGPoint(x: arr[0], y: arr[1]) }

        // ---------- 背景：阴影 / 键盘 / 键帽 / 鼠标（都在猫之下）
        context.drawLayer { l in
            l.opacity = 0.42
            image("shadow", into: &l)
        }
        image("keyboard", into: &context)
        drawKeycaps(frame.keycaps, assets: assets, m: m, in: &context)
        context.drawLayer { l in
            l.opacity = 0.98
            l.translateBy(x: 0, y: frame.pawMouse * 2.5)
            l.translateBy(x: 0, y: frame.mousePress * 2.0)
            l.scaleBy(x: 1 + frame.mousePress * 0.02, y: 1 - frame.mousePress * 0.03)
            image("mouse", into: &l)
        }

        // ---------- 躯干坐标系
        let hip = point(rig.hip)
        let neck = point(rig.neck)
        let breathe = frame.breath
        let squash = 1 + rig.torsoBreathe * breathe

        context.drawLayer { bodyLayer in
            bodyLayer.translateBy(x: hip.x, y: hip.y + frame.torsoLift)
            bodyLayer.rotate(by: .degrees(frame.torsoDeg))
            bodyLayer.scaleBy(x: 1 + 0.012 * breathe, y: squash)
            bodyLayer.translateBy(x: -hip.x, y: -hip.y)

            image("torso", into: &bodyLayer)

            // 尾巴：两段，第二段滞后跟随
            let tailRoot = point(rig.tailRoot)
            let tailMid = point(rig.tailMid)
            bodyLayer.drawLayer { t in
                t.translateBy(x: tailRoot.x, y: tailRoot.y)
                t.rotate(by: .degrees(frame.tail1Deg))
                t.translateBy(x: -tailRoot.x, y: -tailRoot.y)
                image("tail1", into: &t)
                t.drawLayer { t2 in
                    t2.translateBy(x: tailMid.x, y: tailMid.y)
                    t2.rotate(by: .degrees(frame.tail2Deg))
                    t2.translateBy(x: -tailMid.x, y: -tailMid.y)
                    image("tail2", into: &t2)
                }
            }

            // 前臂（含爪）：绕肩转 + 下压 + 左右跟随
            for side in [0, 1] {
                let isLeft = side == 0
                let shoulder = point(isLeft ? rig.shoulderL : rig.shoulderR)
                let deg = isLeft ? frame.armLDeg : frame.armRDeg
                let push = isLeft ? frame.armLPush : frame.armRPush
                let slide = isLeft ? frame.armLSlide : frame.armRSlide
                bodyLayer.drawLayer { a in
                    a.translateBy(x: shoulder.x + slide, y: shoulder.y + push)
                    a.rotate(by: .degrees(deg))
                    a.translateBy(x: -shoulder.x, y: -shoulder.y)
                    image(isLeft ? "armL" : "armR", into: &a)
                }
            }

            // 颈 → 头 → 耳 → 眼（同一坐标系，整头一起转）
            let pitch = frame.headPitch + frame.bob
            bodyLayer.drawLayer { h in
                h.translateBy(x: neck.x, y: neck.y + pitch)
                h.rotate(by: .degrees(frame.headYaw))
                h.translateBy(x: -neck.x, y: -neck.y)
                image("neck", into: &h)
                image("head", into: &h)
                for (ear, deg) in [("earL", frame.earLDeg), ("earR", frame.earRDeg)] {
                    guard let pivot = m.pivot(for: ear) else { continue }
                    h.drawLayer { e in
                        e.translateBy(x: pivot.x, y: pivot.y)
                        e.rotate(by: .degrees(deg))
                        e.translateBy(x: -pivot.x, y: -pivot.y)
                        image(ear, into: &e)
                    }
                }
                drawEye("iris_l", "pupil_l", assets: assets, m: m, frame: frame, in: &h)
                drawEye("iris_r", "pupil_r", assets: assets, m: m, frame: frame, in: &h)
                drawEyelids(rig: rig, frame: frame, in: &h)
            }
        }
    }

    private static func drawEye(_ iris: String, _ pupil: String,
                                assets: PetV6Assets, m: PetV6Manifest,
                                frame: PetRasterFrame, in context: inout GraphicsContext) {
        let rig = m.rig
        let isLeft = iris.hasSuffix("_l")
        let center = CGPoint(x: (isLeft ? rig.eyeL : rig.eyeR)[0], y: (isLeft ? rig.eyeL : rig.eyeR)[1])
        let r = isLeft ? rig.eyeRadius[0] : rig.eyeRadius[1]

        let gaze = CGSize(width: frame.eyeX, height: frame.eyeY)
        let pupilOff = CGSize(width: frame.pupilX, height: frame.pupilY)

        for (name, off, limit) in [(iris, gaze, r * 0.34), (pupil, pupilOff, r * 0.62)] {
            guard let img = assets.images[name], let sz = assets.sizes[name] else { continue }
            let dx = min(max(off.width, -limit), limit)
            let dy = min(max(off.height, -limit), limit)
            let w = m.pt(sz.width), h = m.pt(sz.height)
            let rect = CGRect(x: center.x - w / 2 + dx,
                              y: center.y - h / 2 + dy,
                              width: w, height: h)
            context.draw(img, in: rect)
        }
    }

    private static func drawEyelids(rig: PetV6Manifest.Rig, frame: PetRasterFrame, in context: inout GraphicsContext) {
        let k = min(max(frame.blink, 0), 1)
        guard k > 0.02 else { return }
        for isLeft in [true, false] {
            let c = CGPoint(x: (isLeft ? rig.eyeL : rig.eyeR)[0], y: (isLeft ? rig.eyeL : rig.eyeR)[1])
            let r = isLeft ? rig.eyeRadius[0] : rig.eyeRadius[1]
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2 * k + 1)
            context.fill(Path(rect), with: .color(Color(red: 0.10, green: 0.095, blue: 0.09)))
        }
    }

    private static func drawKeycaps(_ keycaps: [PetKeycap], assets: PetV6Assets, m: PetV6Manifest,
                                    in context: inout GraphicsContext) {
        guard !keycaps.isEmpty, let cap = assets.images["keycap"], let capSize = assets.sizes["keycap"] else { return }
        let g = m.keyboardGrid
        let rise = m.rig.keycapRise
        let capW = m.pt(capSize.width), capH = m.pt(capSize.height)

        for key in keycaps {
            let p = min(max(key.progress, 0), 1)
            // 三段：弹起（快）→ 悬停 → 回落淡出
            var lift: CGFloat = 0
            var opacity: CGFloat = 1
            if p < 0.18 {
                lift = rise * (1 - pow(1 - p / 0.18, 3))
            } else if p < 0.62 {
                lift = rise
            } else {
                let q = (p - 0.62) / 0.38
                lift = rise * (1 - pow(q, 2))
                opacity = 1 - q * q
            }
            let col = CGFloat(min(max(key.column, 0), 12))
            let row = CGFloat(min(max(key.row, 0), 3))
            let center = CGPoint(x: g.colStartX + col * g.colGap,
                                 y: g.backRowY + row * g.rowGap - lift)
            context.drawLayer { layer in
                layer.opacity = Double(opacity)
                layer.translateBy(x: center.x, y: center.y)
                layer.rotate(by: .degrees(key.slot % 2 == 0 ? -2.5 : 2.5))
                let rect = CGRect(x: -capW / 2, y: -capH / 2, width: capW, height: capH)
                layer.draw(cap, in: rect)
                layer.draw(Text(key.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.18, blue: 0.17)),
                           at: CGPoint(x: 0, y: -1))
            }
        }
    }
}
