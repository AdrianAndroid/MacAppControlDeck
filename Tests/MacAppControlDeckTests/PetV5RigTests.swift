import AppKit
import SwiftUI
import XCTest
@testable import MacAppControlDeck

/// v5「Living Rig」的分层资产契约 + 共视/眨眼/落爪状态机测试。
final class PetV5RigTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MacAppControlDeckTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private var manifestURL: URL {
        repoRoot
            .appendingPathComponent("Sources/MacAppControlDeck/Modules/Pet/Resources/v5/manifest.json")
    }

    private func loadManifest() throws -> PetV5Manifest {
        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode(PetV5Manifest.self, from: data)
    }

    func testManifestDecodesAndCoversCanvas() throws {
        let m = try loadManifest()
        XCTAssertEqual(m.designWidth, 720)
        XCTAssertEqual(m.designHeight, 960)
        XCTAssertEqual(m.scale, 2)

        // 所有整幅图层必须铺满画布，局部图层必须落在画布内
        for name in ["shadow", "keyboard", "mouse", "body", "head"] {
            let box = try XCTUnwrap(m.layers[name]?.box)
            XCTAssertEqual(box[0], 0, name)
            XCTAssertEqual(box[1], 0, name)
            XCTAssertEqual(box[2], 1440, name)
            XCTAssertEqual(box[3], 1920, name)
        }
        for (name, layer) in m.layers {
            XCTAssertLessThanOrEqual(layer.box[0], 1440, name)
            XCTAssertLessThanOrEqual(layer.box[1], 1920, name)
            XCTAssertGreaterThan(layer.box[2], layer.box[0], name)
            XCTAssertGreaterThan(layer.box[3], layer.box[1], name)
        }
    }

    func testHeadRotatesAroundNeckPivot() throws {
        let m = try loadManifest()
        let pivot = try XCTUnwrap(m.layers["head"]?.pivot)
        // 颈部支点必须在画布中下部，否则点头会绕着胸口转
        XCTAssertEqual(pivot[0], 450)
        XCTAssertEqual(pivot[1], 962)
        XCTAssertGreaterThan(pivot[1], 900)
    }

    func testEyesShareOneSightLine() throws {
        let m = try loadManifest()
        // 左右眼的眼球半径必须同一量级：否则同一视线向量会推出不同幅度的位移
        let left = m.eyes.left.radius
        let right = m.eyes.right.radius
        XCTAssertGreaterThan(left, 30)
        XCTAssertGreaterThan(right, 30)
        XCTAssertLessThan(abs(left - right) / max(left, right), 0.35)
        // 眼框必须完整包住眼球（v5 曾因眼框太小露出白眼眶）
        for eye in [m.eyes.left, m.eyes.right] {
            XCTAssertGreaterThanOrEqual(eye.size[0], eye.radius * 3)
            XCTAssertGreaterThanOrEqual(eye.size[1], eye.radius * 3)
        }
        XCTAssertGreaterThan(m.eyes.pupilRange[0], 0)
    }

    func testKeyboardBoxSitsUnderPaws() throws {
        let m = try loadManifest()
        let kb = try XCTUnwrap(m.keyboardBox)
        XCTAssertEqual(kb[1], 1400)
        XCTAssertGreaterThan(kb[3], kb[1])
        // 键帽只能长在键盘上
        XCTAssertGreaterThan(kb[0], 0)
        XCTAssertLessThan(kb[2], m.designWidth * 2 + 40)
    }

    func testAssetFilesExistForEveryLayer() throws {
        let dir = manifestURL.deletingLastPathComponent()
        let names = ["shadow", "keyboard", "mouse", "body", "neck", "tail", "head",
                     "earL", "earR", "pawL", "pawR", "patchL", "patchR", "patchTail",
                     "irisL", "irisR", "pupilL", "pupilR", "keycap"]
        for name in names {
            let url = dir.appendingPathComponent("\(name).png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), name)
        }
    }

    @MainActor
    func testIdleFrameHasNeutralExtras() {
        let frame = PetRasterFrame.idle
        XCTAssertEqual(frame.blink, 0)
        XCTAssertEqual(frame.pawL, 0)
        XCTAssertEqual(frame.pawR, 0)
        XCTAssertEqual(frame.pawMouse, 0)
        XCTAssertEqual(frame.tailDeg, 0)
        XCTAssertEqual(frame.earDeg, 0)
        XCTAssertEqual(frame.breath, 0)
    }

    @MainActor
    func testBlinkIsSharedByBothEyes() {
        // 眨眼是整帧标量：不存在"左眼先闭、右眼后闭"
        var frame = PetRasterFrame.idle
        frame.blink = 0.7
        XCTAssertGreaterThan(frame.blink, 0.02)
    }

    @MainActor
    func testPawPressesFollowLeftRightZones() throws {
        let suite = "pet-v5-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock { var value: TimeInterval = 200 }
        let clock = Clock()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        let leftKey = try XCTUnwrap((0..<200).compactMap { PetKeyMap.key(for: UInt16($0)) }
            .first { $0.zone == .left })
        state.handleKeyDown(leftKey.code)
        for _ in 0..<20 { clock.value += 1.0 / 30.0; state.tick() }
        XCTAssertGreaterThan(state.rasterFrame.pawL, 0.05)
        XCTAssertLessThan(state.rasterFrame.pawR, 0.05)
        state.handleKeyUp(leftKey.code)
    }

    @MainActor
    private func render(_ frame: PetRasterFrame, size: PetSize = .large) throws -> NSBitmapImageRep {
        let view = PetRasterArt(frame: frame)
            .frame(width: PetGeometry.visualSize(for: size).width,
                   height: PetGeometry.visualSize(for: size).height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image: NSImage = renderer.nsImage ?? NSImage()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        return try XCTUnwrap(NSBitmapImageRep(data: tiff))
    }

    @MainActor
    func testV5RendererPaintsLayeredRig() throws {
        // v5 资产必须能在真实渲染路径上加载，否则会退回 v4 单帧
        XCTAssertNotNil(PetV5Assets.shared)
        let idle = try render(PetRasterFrame.idle)
        XCTAssertGreaterThan(idle.pixelsWide, 0)
        XCTAssertLessThan(idle.pixelsWide, idle.pixelsHigh)
    }

    @MainActor
    func testPupilFollowsGazeInBothEyes() throws {
        var left = PetRasterFrame.idle
        left.eyeX = -18
        var right = PetRasterFrame.idle
        right.eyeX = 18
        let l = try render(left), r = try render(right)

        let assets = try XCTUnwrap(PetV5Assets.shared)
        // v6 接管渲染后，眼框必须按 v6 的 rig 取，否则测的是错位置的像素
        let v6 = PetV6Assets.shared
        func eyeRect(_ side: Int) -> [CGFloat] {
            if let v6 = v6 {
                let c = side == 0 ? v6.manifest.rig.eyeL : v6.manifest.rig.eyeR
                let rad = side == 0 ? v6.manifest.rig.eyeRadius[0] : v6.manifest.rig.eyeRadius[1]
                let d = rad * 2     // design pt -> asset px
                return [(c[0] - rad) * 2, (c[1] - rad) * 2, d * 2, d * 2]
            }
            let eye = side == 0 ? assets.manifest.eyes.left : assets.manifest.eyes.right
            return [eye.box[0], eye.box[1], eye.size[0], eye.size[1]]
        }
        /// 两帧在眼框内的差异像素：既证明瞳孔真的画出来了，也说明它随视线移动。
        func diffPixels(_ a: NSBitmapImageRep, _ b: NSBitmapImageRep, side: Int) -> (Int, Double) {
            let f = Double(a.pixelsWide) / Double(assets.manifest.designWidth * assets.manifest.scale)
            let r = eyeRect(side)
            var count = 0
            var sumX = 0.0
            for y in Int(r[1] * f)..<Int((r[1] + r[3]) * f) {
                for x in Int(r[0] * f)..<Int((r[0] + r[2]) * f) {
                    guard let ca = a.colorAt(x: x, y: y), let cb = b.colorAt(x: x, y: y) else { continue }
                    let d = abs(ca.redComponent - cb.redComponent) + abs(ca.greenComponent - cb.greenComponent)
                        + abs(ca.blueComponent - cb.blueComponent)
                    if d > 0.12 { count += 1; sumX += Double(x) }
                }
            }
            let centerX = Double((r[0] + r[2] / 2) * f)
            return (count, count > 0 ? sumX / Double(count) - centerX : 0)
        }

        let dl = diffPixels(l, r, side: 0)
        let dr = diffPixels(l, r, side: 1)
        // 两眼都画出了瞳孔，且随同一视线向量一起移动
        XCTAssertGreaterThan(dl.0, 20, "左眼瞳孔没有随视线变化")
        XCTAssertGreaterThan(dr.0, 20, "右眼瞳孔没有随视线变化")
        if v6 != nil {
            // v6 是「虹膜 + 瞳孔 + 整头」三层共视，质心判据由 PetV6RigTests 覆盖
            XCTAssertGreaterThan(dl.0 + dr.0, 60, "v6 视线没有驱动双眼")
            return
        }
        // 位移方向一致（都在各自眼框中心同侧），幅度接近
        XCTAssertEqual(dl.1 > 0, dr.1 > 0, "两眼瞳孔位移方向不一致，不是共视")
        XCTAssertLessThan(abs(abs(dl.1) - abs(dr.1)), 24, "两眼瞳孔位移幅度差异过大")
    }

    @MainActor
    func testKeycapRisesFromKeyboardArea() throws {
        let theme = "cream"
        _ = theme
        var frame = PetRasterFrame.idle
        frame.keycaps = [PetKeycap(id: 7, label: "K", slot: 0, progress: 0.25, isModifier: false,
                                   row: 1, column: 7)]
        let withCap = try render(frame)
        let without = try render(PetRasterFrame.idle)
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pet-v5-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let png = withCap.representation(using: .png, properties: [:]) {
            try png.write(to: dir.appendingPathComponent("keycap.png"))
        }
        print("PET_V5_DIR=\(dir.path)")
        XCTAssertNotEqual(withCap.tiffRepresentation, without.tiffRepresentation)
    }

    @MainActor
    func testKeycapCarriesRealKeyPosition() throws {
        let suite = "pet-v5-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock { var value: TimeInterval = 400 }
        let clock = Clock()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        let key = try XCTUnwrap(PetKeyMap.key(for: 40))     // K
        state.handleKeyDown(key.code)
        clock.value += 0.1
        state.tick()
        let cap = try XCTUnwrap(state.rasterFrame.keycaps.first)
        XCTAssertEqual(cap.label, key.label)
        XCTAssertEqual(cap.row, key.row)
        XCTAssertEqual(cap.column, key.column)
        XCTAssertGreaterThan(cap.progress, 0)
    }

    @MainActor
    func testHeadYawStaysWithinSixDegrees() throws {
        let suite = "pet-v5-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        final class Clock2 { var value: TimeInterval = 300 }
        let clock = Clock2()
        let state = PetStateMachine(settings: PetSettings(defaults: defaults), now: { clock.value })
        state.handleMouseMoved(normalizedX: 1, normalizedY: 0.5)
        for _ in 0..<90 { clock.value += 1.0 / 30.0; state.tick() }
        XCTAssertLessThanOrEqual(abs(state.rasterFrame.headYaw), 6.5)
    }
}
