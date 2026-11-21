import Combine
import Foundation
import LunarSwift

/// 当前打开的日历窗口的数据源。它不是一个全局单例，窗口关闭后由 CalendarRuntime 一起释放。
@MainActor
final class CalendarStore: ObservableObject {
    @Published private(set) var monthAnchor: Date
    @Published private(set) var days: [CalendarDay] = []
    @Published private(set) var selectedDate: Date
    @Published private(set) var nextHolidayText: String = ""

    private let calendar: Calendar
    private let preferences: CalendarPreferences

    init(preferences: CalendarPreferences = .shared, now: Date = Date()) {
        self.preferences = preferences
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        self.calendar = calendar

        let monthStart = Self.startOfMonth(now, calendar: calendar)
        monthAnchor = monthStart
        selectedDate = now
        refresh()
    }

    var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: monthAnchor)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    var monthGanzhi: String {
        guard let first = days.first(where: { $0.isCurrentMonth }) else { return "" }
        return "\(first.ganzhiYear)年 · \(first.zodiac)年"
    }

    var selectedDay: CalendarDay? {
        if let day = days.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) }) {
            return day
        }
        return CalendarDayBuilder.make(date: selectedDate, currentMonth: monthAnchor, calendar: calendar)
    }

    func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: monthAnchor) else { return }
        let isCurrentMonth = calendar.isDate(newMonth, equalTo: Date(), toGranularity: .month)
        let target = isCurrentMonth ? Date() : Self.startOfMonth(newMonth, calendar: calendar)
        load(month: newMonth, selecting: target)
    }

    func goToday() {
        load(month: Date(), selecting: Date())
    }

    func select(_ day: CalendarDay) {
        if day.isCurrentMonth {
            selectedDate = day.date
        } else {
            load(month: day.date, selecting: day.date)
        }
    }

    private func load(month: Date, selecting date: Date) {
        monthAnchor = Self.startOfMonth(month, calendar: calendar)
        selectedDate = date
        refresh()
    }

    private func refresh() {
        let monthStart = Self.startOfMonth(monthAnchor, calendar: calendar)
        let weekday = calendar.component(.weekday, from: monthStart)
        let leading: Int
        if preferences.weekStartsOnMonday {
            leading = (weekday + 5) % 7
        } else {
            leading = weekday - 1
        }

        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else {
            days = []
            nextHolidayText = ""
            return
        }

        var result: [CalendarDay] = []
        result.reserveCapacity(42)
        for index in 0..<42 {
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { continue }
            result.append(CalendarDayBuilder.make(date: date, currentMonth: monthStart, calendar: calendar))
        }
        days = result
        nextHolidayText = Self.makeCountdown(calendar: calendar)
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func countdownText() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        return makeCountdown(calendar: calendar)
    }

    private static func makeCountdown(calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: Date())
        let currentYear = calendar.component(.year, from: today)
        var candidates: [(date: Date, name: String)] = []
        var seen = Set<String>()

        for year in [currentYear, currentYear + 1, currentYear + 2] {
            for holiday in HolidayUtil.getHolidaysByYear(year: year) where !holiday.work {
                guard !seen.contains(holiday.day) else { continue }
                seen.insert(holiday.day)

                let parts = holiday.day.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3 else { continue }
                var components = DateComponents()
                components.year = parts[0]
                components.month = parts[1]
                components.day = parts[2]
                guard let date = calendar.date(from: components) else { continue }
                let name = holiday.name.replacingOccurrences(of: "节", with: "")
                candidates.append((date, name.isEmpty ? holiday.name : name))
            }
        }

        guard let next = candidates
            .filter({ $0.date >= today })
            .sorted(by: { $0.date < $1.date })
            .first
        else {
            return "暂无节假日数据"
        }

        let days = calendar.dateComponents([.day], from: today, to: next.date).day ?? 0
        if days == 0 {
            return "今天是\(next.name)"
        }
        return "距离 \(next.date.yearText(calendar: calendar))\(next.name) 还有 \(days) 天"
    }
}

private extension Date {
    func yearText(calendar: Calendar) -> String {
        let year = calendar.component(.year, from: self)
        return "\(year)年"
    }
}
