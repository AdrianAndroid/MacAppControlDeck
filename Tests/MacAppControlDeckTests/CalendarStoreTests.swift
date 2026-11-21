import XCTest
@testable import MacAppControlDeck

@MainActor
final class CalendarStoreTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return calendar
    }

    func testKnownLunarDateAndAlmanac() {
        let target = date(2026, 11, 21)
        let day = CalendarDayBuilder.make(date: target, currentMonth: target, calendar: calendar())

        XCTAssertEqual(day.lunarFull, "十月十三")
        XCTAssertEqual(day.ganzhiYear, "丙午")
        XCTAssertEqual(day.zodiac, "马")
        XCTAssertFalse(day.yi.isEmpty)
        XCTAssertFalse(day.ji.isEmpty)
    }

    func testMonthGridHas42DaysAndContainsSelectedDate() {
        let store = CalendarStore(preferences: .shared, now: date(2026, 11, 21))

        XCTAssertEqual(store.days.count, 42)
        XCTAssertTrue(store.days.contains { $0.year == 2026 && $0.month == 11 && $0.day == 21 })
        XCTAssertEqual(store.days.filter(\.isCurrentMonth).count, 30)
    }

    func testHolidayBadgeForNationalDay() {
        let target = date(2026, 10, 1)
        let day = CalendarDayBuilder.make(date: target, currentMonth: target, calendar: calendar())

        XCTAssertEqual(day.holidayBadge, "休")
        XCTAssertEqual(day.holidayName, "国庆节")
    }

    func testCountdownMentionsUpcomingHoliday() {
        let text = CalendarStore.countdownText()
        XCTAssertFalse(text.isEmpty)
        XCTAssertFalse(text == "暂无节假日数据")
    }
}
