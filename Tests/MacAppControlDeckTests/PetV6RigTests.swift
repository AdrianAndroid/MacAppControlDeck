import AppKit
import SwiftUI
import XCTest
@testable import MacAppControlDeck

/// v6「全身骨骼」契约测试：分层齐全 + 躯干/手臂/尾/头/眼联动。
final class PetV6RigTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var dir: URL {
        repoRoot.appendingPathComponent("Sources/MacAppControlDeck/Modules/Pet/Resources/v6")
    }

    private func loadManifest() throws -> PetV6Manifest {
        let data = try Data(contentsOf: dir.appendingPathComponent("manifest.json"))
        return try JSONDecoder().decode(PetV6Manifest.self, from: data)
    }

    func testManifestCoversTwelveLayers() throws {
        let m = try loadManifest()
        XCTAssertEqual(m.designWidth, 720)
        XCTAssertEqual(m.designHeight, 960)
        XCTAssertEqual(m.scale, 2)

        let required = ["shadow", "keyboard", "keycap", "mouse", "torso", "neck", "head",
                        "earL", "earR", "armL", "armR", "tail1", "tail2",
                        "iris_l", "iris_r", "pupil_l", "pupil_r"]
        for name in required {
            XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("\(name).png").path), name)
            let layer = try XCTUnwrap(m.layers[name], name)
            XCTAssertEqual(layer.box.count, 4, name)
            XCTAssertGreaterThan(layer.box[2], 0, "宽度必须为正 \(name)")
            XCTAssertGreaterThan(layer.box[3], 0, "高度必须为正 \(name)")
            XCTAssertLessThanOrEqual(layer.box[0] + layer.box[2], m.canvas[0], name)
            XCTAssertLessThanOrEqual(layer.box[1] + layer.box[3], m.canvas[1], name)
        }
        // 精灵必须真的裁小了：不许整幅画布塞进每一层
        XCTAssertLessThan(m.layers["armL"]!.box[2], m.canvas[0])
    }

    func testRigPivotsLiveInsideCanvas() throws {
        let m = try loadManifest()
        let pts: [(String, [CGFloat])] = [
            ("neck", m.rig.neck), ("hip", m.rig.hip),
            ("shoulderL", m.rig.shoulderL), ("shoulderR", m.rig.shoulderR),
            ("pawL", m.rig.pawL), ("pawR", m.rig.pawR),
            ("tailRoot", m.rig.tailRoot), ("tailMid", m.rig.tailMid),
            ("earLBase", m.rig.earLBase), ("earRBase", m.rig.earRBase),
            ("eyeL", m.rig.eyeL), ("eyeR", m.rig.eyeR)
        ]
        for (name, p) in pts {
            XCTAssertGreaterThan(p[0], 0, name)
            XCTAssertLessThan(p[0], m.designWidth, name)
            XCTAssertGreaterThan(p[1], 0, name)
            XCTAssertLessThan(p[1], m.designHeight, name)
        }
        // 肩在髋之上（y 向下）：躯干绕髋转时手臂才会被带着走
        XCTAssertLessThan(m.rig.shoulderL[1], m.rig.hip[1])
        XCTAssertLessThan(m.rig.tailRoot[1], m.rig.hip[1] + 120)
        // 两只爪子必须落在键盘横向范围内
        let kb = m.keyboardGrid.box
        for paw in [m.rig.pawL, m.rig.pawR] {
            XCTAssertTrue(paw[0] > kb[0] && paw[0] < kb[0] + kb[2], "爪子跑出键盘")
        }
        XCTAssertGreaterThan(m.rig.keycapRise, 60, "键帽弹起高度必须够看得见")
    }

    @MainActor
    private func render(_ frame: PetRasterFrame) throws -> NSBitmapImageRep {
        let size = PetGeometry.visualSize(for: .large)
        let renderer = ImageRenderer(content: PetRasterArt(frame: frame)
            .frame(width: size.width, height: size.height))
        renderer.scale = 2
        guard let ns = renderer.nsImage,
              let tiff = ns.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw XCTSkip("渲染失败")
        }
        return rep
    }

    /// 只统计某个图层的屏幕区域内的差异像素
    @MainActor
    private func diff(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, layer: String) throws -> Int {
        let m = try loadManifest()
        let box = try XCTUnwrap(m.layers[layer]?.box)
        let f = Double(a.pixelsWide) / Double(m.canvas[0])
        var count = 0
        for y in stride(from: Int(box[1] * f), to: Int((box[1] + box[3]) * f), by: 2) {
            for x in stride(from: Int(box[0] * f), to: Int((box[0] + box[2]) * f), by: 2) {
                guard let ca = a.colorAt(x: x, y: y), let cb = b.colorAt(x: x, y: y) else { continue }
                let d = abs(ca.redComponent - cb.redComponent)
                    + abs(ca.greenComponent - cb.greenComponent)
                    + abs(ca.blueComponent - cb.blueComponent)
                if d > 0.08 { count += 1 }
            }
        }
        return count
    }

    @MainActor
    func testTorsoTiltDragsHeadArmsAndTail() throws {
        let idle = try render(.idle)
        var tilted = PetRasterFrame.idle
        tilted.torsoDeg = 3.4
        let moved = try render(tilted)
        // 躯干一动，头/手臂/尾巴必须跟着走：这是旧版局部 rig 的反例判据
        for name in ["head", "armL", "armR", "tail1", "tail2"] {
            let d = try diff(idle, moved, layer: name)
            XCTAssertGreaterThan(d, 24, "\(name) 没有跟着躯干一起动")
        }
    }

    @MainActor
    func testArmPressMovesWholeForearm() throws {
        let idle = try render(.idle)
        var pressed = PetRasterFrame.idle
        pressed.armLDeg = -9
        pressed.armLPush = 26
        pressed.armLSlide = 6
        let down = try render(pressed)
        let d = try diff(idle, down, layer: "armL")
        XCTAssertGreaterThan(d, 120, "按下的那只前臂没有整条动")
        // 没按的那只手不应该跟着大幅移动
        let other = try diff(idle, down, layer: "armR")
        XCTAssertLessThan(other, 400, "另一只手被误带动")
    }

    @MainActor
    func testTailSegmentsHavePhaseLag() throws {
        let a = try render(PetRasterFrame.idle)
        var f = PetRasterFrame.idle
        f.tail1Deg = 5
        f.tail2Deg = -7
        let b = try render(f)
        XCTAssertGreaterThan(try diff(a, b, layer: "tail2"), 60, "尾尖没有摆动")
    }

    @MainActor
    func testKeycapRisesAboveKeyboard() throws {
        var f = PetRasterFrame.idle
        f.keycaps = [PetKeycap(id: 1, label: "K", slot: 0, progress: 0.3,
                               isModifier: false, row: 1, column: 6)]
        let withCap = try render(f)
        let without = try render(.idle)
        XCTAssertNotEqual(withCap.tiffRepresentation, without.tiffRepresentation)
        let d = try diff(without, withCap, layer: "keyboard")
        XCTAssertGreaterThan(d, 40, "键帽没有从键盘上弹起")
    }

    @MainActor
    func testGazeDrivesIrisAndPupilTogether() throws {
        var left = PetRasterFrame.idle
        left.eyeX = -11; left.pupilX = -9
        var right = PetRasterFrame.idle
        right.eyeX = 11; right.pupilX = 9
        let l = try render(left), r = try render(right)
        let m = try loadManifest()
        let f = Double(l.pixelsWide) / Double(m.canvas[0])

        func centroidDelta(_ side: Int) -> (Int, Double) {
            let c = side == 0 ? m.rig.eyeL : m.rig.eyeR
            let rad = side == 0 ? m.rig.eyeRadius[0] : m.rig.eyeRadius[1]
            var sum = 0.0, count = 0
            let x0 = Int((c[0] - rad) * 2 * f), x1 = Int((c[0] + rad) * 2 * f)
            let y0 = Int((c[1] - rad) * 2 * f), y1 = Int((c[1] + rad) * 2 * f)
            for y in stride(from: y0, to: y1, by: 1) {
                for x in stride(from: x0, to: x1, by: 1) {
                    guard let a2 = l.colorAt(x: x, y: y), let b2 = r.colorAt(x: x, y: y) else { continue }
                    let d = abs(a2.redComponent - b2.redComponent)
                        + abs(a2.greenComponent - b2.greenComponent)
                        + abs(a2.blueComponent - b2.blueComponent)
                    if d > 0.1 { sum += Double(x); count += 1 }
                }
            }
            let center = Double(c[0] * 2) * f
            return (count, count > 0 ? sum / Double(count) - center : 0)
        }

        let dl = centroidDelta(0), dr = centroidDelta(1)
        XCTAssertGreaterThan(dl.0, 60, "左眼没有随视线移动")
        XCTAssertGreaterThan(dr.0, 60, "右眼没有随视线移动")
        XCTAssertEqual(dl.1 > 0, dr.1 > 0, "两眼不共视")
    }

    @MainActor
    func testBreatheAndBlinkStaySubtle() throws {
        var f = PetRasterFrame.idle
        f.breath = 1
        let b = try render(f)
        let idle = try render(.idle)
        XCTAssertLessThan(try diff(idle, b, layer: "torso"), 9000, "呼吸幅度过大，会像抽筋")
    }
}
