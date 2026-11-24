import Combine
import Foundation

/// 副屏「下班倒计时」配置。每天同一套时间，暂不区分工作日与节假日。
struct OffWorkConfig: Equatable, Sendable {
    var enabled: Bool
    var startMinute: Int
    var endMinute: Int
    var showSeconds: Bool
    var showInPortrait: Bool

    static let `default` = OffWorkConfig(enabled: false,
                                         startMinute: 9 * 60,
                                         endMinute: 18 * 60 + 30,
                                         showSeconds: true,
                                         showInPortrait: false)

    /// 下班时间不晚于上班时间时视为跨夜班（例如 22:00 → 06:00）。
    var isOvernight: Bool { endMinute <= startMinute }
}

enum OffWorkPhase: String, Codable {
    case before
    case working
    case after
}

/// 下发给副屏页面的快照：页面只做「目标时间 - 现在」的差值显示。
struct OffWorkSnapshot: Codable, Equatable {
    var enabled: Bool
    var phase: OffWorkPhase
    var label: String
    var targetEpoch: Double
    var targetText: String
    var progress: Double
    var countUp: Bool
    var showSeconds: Bool
    var portrait: Bool
    var serverEpoch: Double
}

enum OffWorkCountdown {
    /// 纯函数：给定时间点与配置，算出阶段、目标时间点与文案。跨夜班、已下班正计时都在这里收口。
    static func snapshot(now: Date,
                         config: OffWorkConfig,
                         calendar: Calendar = .current) -> OffWorkSnapshot {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: now)
        let secondsOfDay = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60 + (parts.second ?? 0)
        let start = config.startMinute * 60
        let end = config.endMinute * 60
        let dayStart = calendar.startOfDay(for: now)
        let startDate = dayStart.addingTimeInterval(TimeInterval(start))

        func result(_ phase: OffWorkPhase,
                    _ label: String,
                    target: Date,
                    text: String,
                    progress: Double = 0,
                    countUp: Bool = false) -> OffWorkSnapshot {
            OffWorkSnapshot(enabled: config.enabled,
                            phase: phase,
                            label: label,
                            targetEpoch: target.timeIntervalSince1970,
                            targetText: text,
                            progress: progress,
                            countUp: countUp,
                            showSeconds: config.showSeconds,
                            portrait: config.showInPortrait,
                            serverEpoch: now.timeIntervalSince1970)
        }

        let startText = Self.clockText(config.startMinute)
        let endText = Self.clockText(config.endMinute)

        if config.isOvernight {
            let inWork = secondsOfDay >= start || secondsOfDay < end
            if inWork {
                // 上班后才到今天的下班点；上班前（凌晨）用的是今天的下班点。
                let targetDay = secondsOfDay >= start
                    ? dayStart.addingTimeInterval(86400)
                    : dayStart
                let target = targetDay.addingTimeInterval(TimeInterval(end))
                let total = Double(1440 - config.startMinute + config.endMinute) * 60
                let elapsed = Double((secondsOfDay - start + 1440) % 1440)
                let progress = total > 0 ? min(1, max(0, elapsed / total)) : 0
                return result(.working, "距下班", target: target,
                              text: "\(endText) 下班", progress: progress)
            }
            return result(.before, "距上班", target: startDate, text: "\(startText) 上班")
        }

        if secondsOfDay < start {
            return result(.before, "距上班", target: startDate, text: "\(startText) 上班")
        }
        if secondsOfDay < end {
            let target = dayStart.addingTimeInterval(TimeInterval(end))
            let total = Double(end - start)
            let elapsed = Double(secondsOfDay - start)
            let progress = total > 0 ? min(1, max(0, elapsed / total)) : 0
            return result(.working, "距下班", target: target,
                          text: "\(endText) 下班", progress: progress)
        }
        return result(.after, "已下班", target: startDate,
                      text: "\(startText) 上班 · \(endText) 下班", countUp: true)
    }

    /// 倒计时数字：显示秒时 HH:MM:SS，否则 HH:MM。与页面 JS 的格式保持一致。
    static func durationText(_ seconds: Double, withSeconds: Bool) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return withSeconds
            ? String(format: "%02d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", hours, minutes)
    }

    /// 0210 → "02:10"；用于「09:00 上班」这类小字。
    static func clockText(_ minutes: Int) -> String {
        let normalized = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", normalized / 60, normalized % 60)
    }
}

/// 设置持久化：与天气设置同构，改动后立即通知副屏刷新。
final class OffWorkSettings: ObservableObject {
    static let shared = OffWorkSettings()

    private enum Key {
        static let enabled = "screen.offwork.enabled"
        static let start = "screen.offwork.startMinute"
        static let end = "screen.offwork.endMinute"
        static let seconds = "screen.offwork.showSeconds"
        static let portrait = "screen.offwork.showInPortrait"
    }

    private let defaults: UserDefaults
    private var loading = true

    @Published var enabled: Bool { didSet { save(Key.enabled, enabled) } }
    @Published var startMinute: Int { didSet { save(Key.start, startMinute) } }
    @Published var endMinute: Int { didSet { save(Key.end, endMinute) } }
    @Published var showSeconds: Bool { didSet { save(Key.seconds, showSeconds) } }
    @Published var showInPortrait: Bool { didSet { save(Key.portrait, showInPortrait) } }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let fallback = OffWorkConfig.default
        enabled = defaults.object(forKey: Key.enabled) as? Bool ?? fallback.enabled
        startMinute = defaults.object(forKey: Key.start) as? Int ?? fallback.startMinute
        endMinute = defaults.object(forKey: Key.end) as? Int ?? fallback.endMinute
        showSeconds = defaults.object(forKey: Key.seconds) as? Bool ?? fallback.showSeconds
        showInPortrait = defaults.object(forKey: Key.portrait) as? Bool ?? fallback.showInPortrait
        loading = false
    }

    var config: OffWorkConfig {
        OffWorkConfig(enabled: enabled,
                      startMinute: startMinute,
                      endMinute: endMinute,
                      showSeconds: showSeconds,
                      showInPortrait: showInPortrait)
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        guard !loading else { return }
        ScreenEventHub.notifyChange()
    }
}
