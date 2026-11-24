import XCTest
@testable import MacAppControlDeck

/// 只验证下班倒计时的纯函数状态机：手机页面只做倒数，规则必须在这里收口。
final class OffWorkCountdownTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    private func config(start: Int = 9 * 60, end: Int = 18 * 60 + 30, enabled: Bool = true) -> OffWorkConfig {
        OffWorkConfig(enabled: enabled, startMinute: start, endMinute: end,
                      showSeconds: true, showInPortrait: false)
    }

    func testBeforeWorkCountsToStart() {
        let snapshot = OffWorkCountdown.snapshot(now: date(24, 8, 30, 15), config: config(), calendar: calendar)
        XCTAssertEqual(snapshot.phase, .before)
        XCTAssertEqual(snapshot.label, "距上班")
        XCTAssertEqual(snapshot.targetText, "09:00 上班")
        XCTAssertEqual(snapshot.targetEpoch, date(24, 9, 0).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertFalse(snapshot.countUp)
        XCTAssertEqual(snapshot.progress, 0, accuracy: 0.0001)
    }

    func testWorkingCountsToEndWithProgress() {
        let snapshot = OffWorkCountdown.snapshot(now: date(24, 12, 0), config: config(), calendar: calendar)
        XCTAssertEqual(snapshot.phase, .working)
        XCTAssertEqual(snapshot.label, "距下班")
        XCTAssertEqual(snapshot.targetEpoch, date(24, 18, 30).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(snapshot.progress, 3.0 / 9.5, accuracy: 0.0001)
    }

    func testAfterWorkCountsUpFromStart() {
        let snapshot = OffWorkCountdown.snapshot(now: date(24, 20, 0), config: config(), calendar: calendar)
        XCTAssertEqual(snapshot.phase, .after)
        XCTAssertEqual(snapshot.label, "已下班")
        XCTAssertTrue(snapshot.countUp)
        XCTAssertEqual(snapshot.targetEpoch, date(24, 9, 0).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(snapshot.targetText, "09:00 上班 · 18:30 下班")
    }

    func testBoundarySecondsSwitchPhase() {
        let justBefore = OffWorkCountdown.snapshot(now: date(24, 18, 29, 59), config: config(), calendar: calendar)
        XCTAssertEqual(justBefore.phase, .working)

        let atEnd = OffWorkCountdown.snapshot(now: date(24, 18, 30, 0), config: config(), calendar: calendar)
        XCTAssertEqual(atEnd.phase, .after)
    }

    func testOvernightShift() {
        let shift = config(start: 22 * 60, end: 6 * 60)

        let lateNight = OffWorkCountdown.snapshot(now: date(24, 23, 0), config: shift, calendar: calendar)
        XCTAssertEqual(lateNight.phase, .working)
        XCTAssertEqual(lateNight.label, "距下班")
        XCTAssertEqual(lateNight.targetEpoch, date(25, 6, 0).timeIntervalSince1970, accuracy: 0.001)

        let dawn = OffWorkCountdown.snapshot(now: date(25, 3, 0), config: shift, calendar: calendar)
        XCTAssertEqual(dawn.phase, .working)
        XCTAssertEqual(dawn.targetEpoch, date(25, 6, 0).timeIntervalSince1970, accuracy: 0.001)

        let noon = OffWorkCountdown.snapshot(now: date(25, 12, 0), config: shift, calendar: calendar)
        XCTAssertEqual(noon.phase, .before)
        XCTAssertEqual(noon.label, "距上班")
        XCTAssertEqual(noon.targetEpoch, date(25, 22, 0).timeIntervalSince1970, accuracy: 0.001)
    }

    func testDisabledStillProducesSnapshot() {
        let snapshot = OffWorkCountdown.snapshot(now: date(24, 12, 0), config: config(enabled: false), calendar: calendar)
        XCTAssertFalse(snapshot.enabled)
        XCTAssertEqual(snapshot.phase, .working)
    }

    func testFormatting() {
        XCTAssertEqual(OffWorkCountdown.clockText(9 * 60), "09:00")
        XCTAssertEqual(OffWorkCountdown.clockText(18 * 60 + 30), "18:30")
        XCTAssertEqual(OffWorkCountdown.clockText(1440 + 75), "01:15")
        XCTAssertEqual(OffWorkCountdown.durationText(4 * 3600 + 33 * 60 + 12, withSeconds: true), "04:33:12")
        XCTAssertEqual(OffWorkCountdown.durationText(4 * 3600 + 33 * 60 + 12, withSeconds: false), "04:33")
        XCTAssertEqual(OffWorkCountdown.durationText(-5, withSeconds: true), "00:00:00")
    }
}
