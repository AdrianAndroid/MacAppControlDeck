import Combine
import Foundation

/// 无 UI 的状态机：把鼠标/键盘目标转换为骨骼目标、视线、键帽与全身边级运动。
@MainActor
final class PetStateMachine: ObservableObject {
    @Published private(set) var snapshot = PetSnapshot.idle
    /// v4 光栅骨架的每帧状态，与 snapshot 同源产出。
    @Published private(set) var rasterFrame = PetRasterFrame.idle
    @Published var skin: PetSkin
    @Published var keyboardTheme: PetKeyboardTheme
    @Published var size: PetSize
    var reduceMotion = false

    private struct Spring {
        var value: CGFloat
        var velocity: CGFloat = 0

        mutating func step(to target: CGFloat, dt: CGFloat, stiffness: CGFloat, damping: CGFloat) {
            let time = min(max(dt, 0), 1.0 / 30.0)
            velocity += (stiffness * (target - value) - damping * velocity) * time
            value += velocity * time
        }
    }

    private struct KeycapState {
        let id: Int
        let label: String
        let slot: Int
        let startedAt: TimeInterval
        let isModifier: Bool
        let row: Int
        let column: Int
    }

    private let now: () -> TimeInterval
    private var lastTick: TimeInterval
    private var lastActivity: TimeInterval
    private var nextBlinkAt: TimeInterval
    private var blinkStartedAt: TimeInterval?
    private var surprisedUntil: TimeInterval = 0
    private var petUntil: TimeInterval = 0
    private var typingUntil: TimeInterval = 0
    private var sleepTimeout: TimeInterval

    private var activeKeys: [UInt16: PetKeyInfo] = [:]
    private var lastLeftKey: UInt16?
    private var lastRightKey: UInt16?
    private var recentKeys: [(code: UInt16, time: TimeInterval)] = []
    private var keycaps: [KeycapState] = []
    private var nextKeycapID = 0
    static let keycapLife: TimeInterval = 0.6
    static let keycapSlots = 4

    private var cursorX: CGFloat = 0
    private var cursorY: CGFloat = 0
    private var gazeCursorX: CGFloat = 0
    private var gazeCursorY: CGFloat = 0
    private var gazeTargetX: CGFloat = 0
    private var gazeTargetY: CGFloat = 0

    private var eyeXSpring = Spring(value: 0)
    private var eyeYSpring = Spring(value: 0)
    private var headYawSpring = Spring(value: 0)
    private var bodyLeanSpring = Spring(value: 0)
    private var leftPawXSpring = Spring(value: PetRigLayout.mouseCenter.x)
    private var leftPawYSpring = Spring(value: PetRigLayout.mouseCenter.y)
    private var rightPawXSpring = Spring(value: PetRigLayout.rightRestPaw.x)
    private var rightPawYSpring = Spring(value: PetRigLayout.rightRestPaw.y)
    private var mouseShiftXSpring = Spring(value: 0)
    private var mouseShiftYSpring = Spring(value: 0)
    private var bodyImpact = Spring(value: 0)
    private var typingFocusSpring = Spring(value: 0)
    private var tailBoost: CGFloat = 0
    private var rasterEyeX = Spring(value: 0)
    private var rasterEyeY = Spring(value: 0)
    private var rasterHeadYaw = Spring(value: 0)
    private var rasterPawL = Spring(value: 0)
    private var rasterPawR = Spring(value: 0)
    private var rasterPawMouse = Spring(value: 0)
    private var mouseClickUntil: TimeInterval = 0
    private var rasterHeadPitch = Spring(value: 0)

    init(settings: PetSettings,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
        let timestamp = now()
        lastTick = timestamp
        lastActivity = timestamp
        nextBlinkAt = timestamp + 3.2
        skin = settings.skin
        keyboardTheme = settings.keyboardTheme
        size = settings.size
        sleepTimeout = TimeInterval(settings.sleepMinutes * 60)
    }

    var configuration: PetRenderConfiguration {
        PetRenderConfiguration(skinID: skin.id, keyboardTheme: keyboardTheme, size: size)
    }

    var keyboardRect: CGRect {
        CGRect(
            x: PetKeyboardLayout.origin.x,
            y: PetKeyboardLayout.origin.y,
            width: PetKeyboardLayout.width,
            height: PetKeyboardLayout.height
        )
    }

    func apply(settings: PetSettings) {
        skin = settings.skin
        keyboardTheme = settings.keyboardTheme
        size = settings.size
        sleepTimeout = TimeInterval(settings.sleepMinutes * 60)
        wake()
    }

    func tick() {
        let timestamp = now()
        let dt = min(max(timestamp - lastTick, 0), 1.0 / 20.0)
        lastTick = timestamp

        let hasKeyboardTarget = !activeKeys.isEmpty
        if !hasKeyboardTarget, timestamp >= typingUntil {
            gazeTargetX = cursorX
            gazeTargetY = cursorY
        }

        let sleepingTarget: CGFloat
        if sleepTimeout > 0, timestamp - lastActivity > sleepTimeout {
            sleepingTarget = 1
            gazeTargetX = 0
            gazeTargetY = -0.12
        } else {
            sleepingTarget = 0
        }

        let typingTarget: CGFloat = hasKeyboardTarget || timestamp < typingUntil ? 1 : 0
        typingFocusSpring.step(to: typingTarget, dt: dt, stiffness: 300, damping: 30)

        eyeXSpring.step(to: gazeTargetX, dt: dt, stiffness: 700, damping: 40)
        eyeYSpring.step(to: gazeTargetY, dt: dt, stiffness: 700, damping: 40)
        headYawSpring.step(
            to: gazeTargetX * 7 + (typingTarget > 0 ? (lastRightKey == nil ? -1.5 : 1.5) : 0),
            dt: dt, stiffness: 240, damping: 28
        )

        var blink: CGFloat = 0
        if typingTarget < 0.2, timestamp >= nextBlinkAt, blinkStartedAt == nil {
            blinkStartedAt = timestamp
            nextBlinkAt = timestamp + TimeInterval.random(in: 2.8...5.6)
        }
        if let started = blinkStartedAt {
            let progress = (timestamp - started) / 0.20
            if progress >= 1 {
                blinkStartedAt = nil
            } else {
                blink = CGFloat(sin(progress * .pi))
            }
        }

        let leftTargetPoint = pawTarget(for: .left)
        let rightTargetPoint = pawTarget(for: .right)
        leftPawXSpring.step(to: leftTargetPoint.x, dt: dt, stiffness: 650, damping: 40)
        leftPawYSpring.step(to: leftTargetPoint.y, dt: dt, stiffness: 650, damping: 40)
        rightPawXSpring.step(to: rightTargetPoint.x, dt: dt, stiffness: 650, damping: 40)
        rightPawYSpring.step(to: rightTargetPoint.y, dt: dt, stiffness: 650, damping: 40)

        let mouseTargetX = cursorX * 4
        let mouseTargetY = cursorY * 2
        mouseShiftXSpring.step(to: mouseTargetX, dt: dt, stiffness: 220, damping: 26)
        mouseShiftYSpring.step(to: mouseTargetY, dt: dt, stiffness: 220, damping: 26)

        bodyImpact.step(to: 0, dt: dt, stiffness: 160, damping: 15)
        let leanTarget = min(max(
            gazeTargetX * 4.5
                + (leftPawXSpring.value - PetRigLayout.mouseCenter.x) * 0.05
                + (rightPawXSpring.value - PetRigLayout.rightRestPaw.x) * 0.02,
            -5.5
        ), 5.5)
        bodyLeanSpring.step(to: leanTarget, dt: dt, stiffness: 220, damping: 28)

        let sleeping = sleepingTarget
        let surprised = timestamp < surprisedUntil ? CGFloat(1) : 0
        let breathing = reduceMotion ? 0 : abs(sin(timestamp * 1.35)) * 0.012
        let tail = reduceMotion ? 0 : sin(timestamp * (sleeping > 0 ? 0.75 : 2.0)) * 0.32 + tailBoost - leanTarget * 0.025
        let ear = reduceMotion ? 0 : sin(timestamp * 3.4) * 0.08
        let leftIntensity = pressIntensity(for: .left, centerWeight: 0.85) * (1 - sleeping)
        let rightIntensity = pressIntensity(for: .right, centerWeight: 0.85) * (1 - sleeping)

        let pressed = activeKeys.values.map {
            PetKeyPress(code: $0.code, label: $0.label, zone: $0.zone, depth: 1)
        }
        let visibleKeycaps = keycaps.compactMap { keycap -> PetKeycap? in
            let progress = CGFloat((timestamp - keycap.startedAt) / Self.keycapLife)
            guard progress < 1 else { return nil }
            return PetKeycap(
                id: keycap.id,
                label: keycap.label,
                slot: keycap.slot,
                progress: max(progress, 0),
                isModifier: keycap.isModifier,
                row: keycap.row,
                column: keycap.column
            )
        }
        keycaps.removeAll { timestamp - $0.startedAt >= Self.keycapLife }

        let zones: Set<PetKeyZone> = Set(pressed.map(\.zone))
        let newSnapshot = PetSnapshot(
            pawLeft: leftIntensity,
            pawRight: rightIntensity,
            leftPawPoint: PetPoint(leftPawXSpring.value, leftPawYSpring.value),
            rightPawPoint: PetPoint(rightPawXSpring.value, rightPawYSpring.value),
            blink: max(blink, sleeping),
            squint: min(typingFocusSpring.value * 0.75 + surprised * 0.1, 0.85),
            eyeX: eyeXSpring.value,
            eyeY: eyeYSpring.value,
            headYaw: headYawSpring.value,
            bodyBounce: breathing + bodyImpact.value,
            bodyLean: bodyLeanSpring.value,
            tailWag: tail,
            earTwitch: ear,
            surprised: surprised,
            sleeping: sleeping,
            mouthOpen: max(surprised * 0.4, dragging ? 0.25 : 0),
            blush: max(dragging ? 0.25 : 0, timestamp < petUntil ? 0.65 : 0),
            dragging: dragging ? 1 : 0,
            mouseShift: PetPoint(mouseShiftXSpring.value, mouseShiftYSpring.value),
            activeZones: zones,
            pressedKeys: pressed,
            keycaps: visibleKeycaps
        )
        if newSnapshot != snapshot {
            snapshot = newSnapshot
        }

        // ---- v4 光栅骨架：全屏视线 + 头部微动 ----
        let gazeX = gazeCursorX
        let gazeY = min(gazeCursorY + (typingTarget > 0 ? 0.22 : 0), 1)
        rasterEyeX.step(to: (gazeX + (reduceMotion ? 0 : sin(timestamp * 1.73) * 0.05)) * 10, dt: dt, stiffness: 520, damping: 34)
        rasterEyeY.step(to: (gazeY + (reduceMotion ? 0 : sin(timestamp * 1.21) * 0.05)) * 6, dt: dt, stiffness: 520, damping: 34)
        // 微扫视：常驻 ±0.08 的细小位移，让共视不至于像贴纸
        let saccadeX = reduceMotion ? 0 : (sin(timestamp * 1.73) * 0.6 + sin(timestamp * 2.31 + 1.1) * 0.4) * 0.08
        let saccadeY = reduceMotion ? 0 : (sin(timestamp * 1.21 + 0.7) * 0.6 + sin(timestamp * 2.77 + 2.3) * 0.4) * 0.05
        rasterHeadYaw.step(to: (gazeX + saccadeX) * 6.0, dt: dt, stiffness: 150, damping: 26)
        rasterHeadPitch.step(to: (gazeY - 0.35 + saccadeY) * 3.2, dt: dt, stiffness: 150, damping: 26)
        let rasterCaps = keycaps.compactMap { keycap -> PetKeycap? in
            let progress = CGFloat((timestamp - keycap.startedAt) / Self.keycapLife)
            guard progress < 1 else { return nil }
            return PetKeycap(id: keycap.id, label: keycap.label, slot: keycap.slot,
                             progress: max(progress, 0), isModifier: keycap.isModifier,
                             row: keycap.row, column: keycap.column)
        }
        // v5：局部爪子 / 眨眼 / 尾耳 / 呼吸
        let leftDown = zones.contains(.left)
        let rightDown = zones.contains(.right)
        let mouseDown = timestamp < mouseClickUntil
        rasterPawL.step(to: reduceMotion ? 0 : (leftDown ? 1 : 0), dt: dt, stiffness: 420, damping: 30)
        rasterPawR.step(to: reduceMotion ? 0 : (rightDown ? 1 : 0), dt: dt, stiffness: 420, damping: 30)
        rasterPawMouse.step(to: reduceMotion ? 0 : (mouseDown ? 1 : 0), dt: dt, stiffness: 380, damping: 28)
        let blinkCycle = timestamp.truncatingRemainder(dividingBy: 4.2)
        let v5Blink = blinkCycle < 0.11 ? CGFloat(sin(Double.pi * blinkCycle / 0.11)) : 0
        let newRaster = PetRasterFrame(
            eyeX: rasterEyeX.value,
            eyeY: rasterEyeY.value,
            headYaw: rasterHeadYaw.value,
            headPitch: rasterHeadPitch.value,
            bob: reduceMotion ? 0 : sin(timestamp * 1.35) * 1.6,
            keycaps: rasterCaps,
            blink: reduceMotion ? 0 : v5Blink,
            pawL: rasterPawL.value,
            pawR: rasterPawR.value,
            pawMouse: rasterPawMouse.value,
            tailDeg: reduceMotion ? 0 : CGFloat(sin(timestamp * 1.76) * 1.8),
            earDeg: reduceMotion ? 0 : CGFloat(sin(timestamp * 2.9) > 0.96 ? 5 : 0),
            breath: reduceMotion ? 0 : CGFloat((sin(timestamp / 4.2 * 2 * Double.pi) + 1) / 2)
        )
        if newRaster != rasterFrame {
            rasterFrame = newRaster
        }
        tailBoost *= 0.9
    }

    private var dragging = false

    func handleKeyDown(_ keyCode: UInt16, isRepeat: Bool = false) {
        wake()
        guard let key = PetKeyMap.key(for: keyCode) else { return }
        let timestamp = now()
        typingUntil = timestamp + 0.55
        gazeTargetX = normalizedX(for: PetKeyboardLayout.center(row: key.row, column: key.column))
        gazeTargetY = normalizedY(for: PetKeyboardLayout.center(row: key.row, column: key.column))

        if isRepeat {
            tick()
            return
        }
        guard activeKeys[keyCode] == nil else { return }
        activeKeys[keyCode] = key
        if key.zone == .left || key.zone == .center { lastLeftKey = keyCode }
        if key.zone == .right || key.zone == .center { lastRightKey = keyCode }
        bodyImpact.velocity -= 26
        addKeycap(label: key.label, isModifier: key.isModifier, row: key.row, column: key.column)

        recentKeys.removeAll { timestamp - $0.time > 0.3 }
        if !recentKeys.contains(where: { $0.code == keyCode }) {
            recentKeys.append((keyCode, timestamp))
        }
        if recentKeys.count >= 3 {
            surprisedUntil = timestamp + 0.85
            recentKeys.removeAll()
        }
        tick()
    }

    func handleKeyUp(_ keyCode: UInt16) {
        guard activeKeys.removeValue(forKey: keyCode) != nil else { return }
        if lastLeftKey == keyCode {
            lastLeftKey = activeKeys.values.filter { $0.zone == PetKeyZone.left || $0.zone == PetKeyZone.center }.last?.code
        }
        if lastRightKey == keyCode {
            lastRightKey = activeKeys.values.filter { $0.zone == PetKeyZone.right || $0.zone == PetKeyZone.center }.last?.code
        }
        tick()
    }

    /// v4 使用：以宠物所在屏幕的可见区域为参照，归一化全屏光标位置。
    func handleGaze(normalizedX: CGFloat, normalizedY: CGFloat) {
        wake()
        gazeCursorX = min(max(normalizedX, -1), 1)
        gazeCursorY = min(max(normalizedY, -1), 1)
    }

    func handleMouseMoved(normalizedX: CGFloat, normalizedY: CGFloat) {
        wake()
        cursorX = min(max(normalizedX, -1), 1)
        cursorY = min(max(normalizedY, -1), 1)
        if now() >= typingUntil {
            gazeTargetX = cursorX
            gazeTargetY = cursorY
        }
        tick()
    }

    /// 真实鼠标点击 → 右爪按鼠标姿态（0.35s 后自动抬起）
    func handleClick(isDown: Bool) {
        guard !reduceMotion else { return }
        if isDown { mouseClickUntil = now() + 0.35 }
    }

    func handleMouseDown(part: PetPart) {
        wake()
        switch part {
        case .head:
            petUntil = now() + 1.2
            bodyImpact.velocity -= 12
        case .leftPaw, .rightPaw:
            bodyImpact.velocity -= 10
        case .keyboard:
            bodyImpact.velocity -= 8
        default:
            break
        }
        tick()
    }

    func handleScroll() {
        wake()
        tailBoost = min(tailBoost + 0.5, 1.2)
        tick()
    }

    func hoverPet() {
        wake()
        petUntil = now() + 1.4
        tick()
    }

    func setDragging(_ value: Bool) {
        dragging = value
        wake()
        tick()
    }

    func wake() {
        lastActivity = now()
        if snapshot.sleeping > 0 {
            snapshot.sleeping = 0
        }
    }

    var isSleeping: Bool { snapshot.sleeping > 0 }

    private func addKeycap(label: String, isModifier: Bool, row: Int = 0, column: Int = 0) {
        if keycaps.count >= Self.keycapSlots {
            keycaps.removeFirst()
        }
        let usedSlots = Set(keycaps.map(\.slot))
        let slot = (0..<Self.keycapSlots).first(where: { !usedSlots.contains($0) }) ?? 0
        keycaps.append(KeycapState(
            id: nextKeycapID,
            label: label,
            slot: slot,
            startedAt: now(),
            isModifier: isModifier,
            row: row,
            column: column
        ))
        nextKeycapID += 1
        while keycaps.count > Self.keycapSlots {
            keycaps.removeFirst()
        }
    }

    private func pawTarget(for side: PetKeyZone) -> PetPoint {
        let code: UInt16?
        switch side {
        case .left:
            code = lastLeftKey
        case .right:
            code = lastRightKey
        default:
            code = nil
        }
        if let code, let center = PetKeyMap.center(for: code) {
            if side == .left {
                return PetPoint(center.x - 3, center.y - 1)
            }
            return PetPoint(center.x + 2, center.y - 1)
        }
        if side == .left {
            return PetPoint(
                PetRigLayout.mouseCenter.x + cursorX * 4 + 3,
                PetRigLayout.mouseCenter.y + cursorY * 2 + 4
            )
        }
        return PetRigLayout.rightRestPaw
    }

    private func pressIntensity(for side: PetKeyZone, centerWeight: CGFloat) -> CGFloat {
        var left: CGFloat = 0
        var right: CGFloat = 0
        for key in activeKeys.values {
            switch key.zone {
            case .left: left = 1
            case .right: right = 1
            case .center:
                left = max(left, centerWeight)
                right = max(right, centerWeight)
            case .function:
                left = max(left, 0.65)
                right = max(right, 0.65)
            case .none:
                break
            }
        }
        return side == .left ? left : right
    }

    private func normalizedX(for point: PetPoint) -> CGFloat {
        min(max((point.x / PetRigLayout.designSize.width - 0.5) * 2, -1), 1)
    }

    private func normalizedY(for point: PetPoint) -> CGFloat {
        min(max((point.y / PetRigLayout.designSize.height - 0.5) * 2, -1), 1)
    }
}
