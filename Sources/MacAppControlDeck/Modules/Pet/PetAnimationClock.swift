import Foundation

/// 空闲 12fps、动作 30fps 的动画时钟。
@MainActor
final class PetAnimationClock {
    private weak var state: PetStateMachine?
    private var timer: Timer?
    private var activeUntil: TimeInterval = 0
    private var interval: TimeInterval = 0
    private var isRunning = false
    var lowPower = false

    init(state: PetStateMachine) {
        self.state = state
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        schedule(interval: 1.0 / 12.0)
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        state = nil
    }

    func kick() {
        guard !lowPower else {
            schedule(interval: 1.0 / 8.0)
            return
        }
        activeUntil = ProcessInfo.processInfo.systemUptime + 2.0
        if interval > 1.0 / 20.0 || interval == 0 {
            schedule(interval: 1.0 / 30.0)
        }
    }

    private func schedule(interval newInterval: TimeInterval) {
        let rounded = round(newInterval * 100) / 100
        if interval == rounded, timer != nil { return }
        interval = rounded
        timer?.invalidate()
        guard isRunning else { return }
        let timer = Timer(timeInterval: newInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleTick()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTick() {
        guard isRunning else { return }
        state?.tick()
        let now = ProcessInfo.processInfo.systemUptime
        if now > activeUntil, interval < 1.0 / 20.0 {
            schedule(interval: 1.0 / 12.0)
        }
    }
}
