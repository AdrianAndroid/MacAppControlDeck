import Combine
import Foundation

/// 无 UI 的桌宠状态机。输入只推进状态，渲染层只读取 snapshot。
@MainActor
final class PetStateMachine: ObservableObject {
    @Published private(set) var snapshot = PetSnapshot.idle
    @Published var skin: PetSkin
    @Published var keyboardTheme: PetKeyboardTheme
    @Published var size: PetSize
    var reduceMotion = false

    private var sleepTimeout: TimeInterval
    private let now: () -> TimeInterval
    private var lastTick: TimeInterval
    private var lastActivity: TimeInterval
    private var nextBlinkAt: TimeInterval
    private var blinkStartedAt: TimeInterval?
    private var surprisedUntil: TimeInterval = 0
    private var dragging = false
    private var eyeX: CGFloat = 0
    private var eyeY: CGFloat = 0
    private var tailBoost: CGFloat = 0
    private var petUntil: TimeInterval = 0
    private var activeKeys: [UInt16: PetKeyZone] = [:]
    private var activeZoneCounts: [PetKeyZone: Int] = [:]
    private var zoneLingerUntil: [PetKeyZone: TimeInterval] = [:]
    private var recentKeys: [(code: UInt16, time: TimeInterval)] = []

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

    func apply(settings: PetSettings) {
        skin = settings.skin
        keyboardTheme = settings.keyboardTheme
        size = settings.size
        sleepTimeout = TimeInterval(settings.sleepMinutes * 60)
        wake()
    }

    func tick() {
        let timestamp = now()
        let delta = min(max(timestamp - lastTick, 0), 0.1)
        lastTick = timestamp

        if timestamp >= nextBlinkAt, blinkStartedAt == nil {
            blinkStartedAt = timestamp
            nextBlinkAt = timestamp + TimeInterval.random(in: 2.8...5.6)
        }
        var blink: CGFloat = 0
        if let started = blinkStartedAt {
            let progress = (timestamp - started) / 0.20
            if progress >= 1 {
                blinkStartedAt = nil
            } else {
                blink = CGFloat(sin(progress * .pi))
            }
        }

        var pawLeft: CGFloat = 0
        var pawRight: CGFloat = 0
        for (zone, count) in activeZoneCounts where count > 0 {
            switch zone {
            case .left: pawLeft = 1
            case .right: pawRight = 1
            case .center:
                pawLeft = 1
                pawRight = 1
            case .function:
                pawLeft = 0.8
                pawRight = 0.8
            case .none: break
            }
        }

        let sleepingTarget: CGFloat
        if sleepTimeout > 0, timestamp - lastActivity > sleepTimeout, !dragging {
            sleepingTarget = 1
        } else {
            sleepingTarget = 0
        }
        let surprised = timestamp < surprisedUntil ? CGFloat(1) : 0
        let bounce = reduceMotion ? 0 : abs(sin(timestamp * 1.5)) * 0.018 + (pawLeft + pawRight) * 0.012
        let tail = reduceMotion ? 0 : sin(timestamp * (sleepingTarget > 0 ? 0.9 : 2.2)) * 0.35 + tailBoost
        let ear = reduceMotion ? 0 : sin(timestamp * 3.6) * 0.08
        let zones = Set(activeZoneCounts.compactMap { $0.value > 0 ? $0.key : nil }
            + zoneLingerUntil.compactMap { timestamp < $0.value ? $0.key : nil })

        eyeX *= 0.92
        eyeY *= 0.92
        tailBoost *= 0.9

        let newSnapshot = PetSnapshot(
            pawLeft: pawLeft * (1 - sleepingTarget),
            pawRight: pawRight * (1 - sleepingTarget),
            blink: max(blink, sleepingTarget),
            eyeX: eyeX,
            eyeY: eyeY,
            bodyBounce: bounce * (1 - sleepingTarget * 0.6),
            tailWag: tail,
            earTwitch: ear,
            surprised: surprised,
            sleeping: sleepingTarget,
            mouthOpen: max(surprised * 0.7, dragging ? 0.35 : 0),
            blush: max(dragging ? 0.25 : 0, timestamp < petUntil ? 0.7 : 0),
            dragging: dragging ? 1 : 0,
            activeZones: zones
        )
        if newSnapshot != snapshot {
            snapshot = newSnapshot
        }
        _ = delta
    }

    func handleKeyDown(_ keyCode: UInt16, isRepeat: Bool = false) {
        wake()
        guard !isRepeat else { return }
        let zone = PetKeyMap.zone(for: keyCode)
        guard zone != .none, activeKeys[keyCode] == nil else { return }
        activeKeys[keyCode] = zone
        activeZoneCounts[zone, default: 0] += 1
        zoneLingerUntil[zone] = now() + 0.36

        let timestamp = now()
        recentKeys.removeAll { timestamp - $0.time > 0.12 }
        if !recentKeys.contains(where: { $0.code == keyCode }) {
            recentKeys.append((keyCode, timestamp))
        }
        if recentKeys.count >= 3 {
            surprisedUntil = timestamp + 0.8
            recentKeys.removeAll()
        }
        tick()
    }

    func handleKeyUp(_ keyCode: UInt16) {
        guard let zone = activeKeys.removeValue(forKey: keyCode) else { return }
        activeZoneCounts[zone, default: 0] -= 1
        if activeZoneCounts[zone, default: 0] <= 0 {
            activeZoneCounts[zone] = 0
        }
        tick()
    }

    func handleMouseMoved(normalizedX: CGFloat, normalizedY: CGFloat) {
        wake()
        eyeX = min(max(normalizedX, -1), 1) * 0.12
        eyeY = min(max(normalizedY, -1), 1) * 0.08
    }

    func handleMouseDown(part: PetPart) {
        wake()
        switch part {
        case .head:
            surprisedUntil = now() + 0.55
        case .leftPaw:
            activeZoneCounts[.left, default: 0] = 1
            zoneLingerUntil[.left] = now() + 0.3
        case .rightPaw:
            activeZoneCounts[.right, default: 0] = 1
            zoneLingerUntil[.right] = now() + 0.3
        case .keyboard:
            zoneLingerUntil[.center] = now() + 0.3
        default:
            break
        }
        tick()
    }

    func handleScroll() {
        wake()
        tailBoost = min(tailBoost + 0.5, 1.2)
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
}
