import Foundation
import LunarSwift

enum CalendarSubtitleKind: Equatable {
    case lunar
    case solarTerm
    case festival
    case other
}

/// 日历格里的一个纯值对象。窗口关闭后随 CalendarStore 一起释放。
struct CalendarDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let year: Int
    let month: Int
    let day: Int
    let yearText: String
    let monthText: String
    let lunarFull: String
    let subtitle: String
    let subtitleKind: CalendarSubtitleKind
    let holidayBadge: String?
    let holidayName: String?
    let isToday: Bool
    let isWeekend: Bool
    let isCurrentMonth: Bool
    let weekText: String
    let ganzhiYear: String
    let zodiac: String
    let ganzhiMonth: String
    let ganzhiDay: String
    let yi: [String]
    let ji: [String]
}

enum CalendarDayBuilder {
    static func make(date: Date, currentMonth: Date, calendar: Calendar) -> CalendarDay {
        let lunar = Lunar.fromDate(date: date)
        let solar = lunar.solar

        let solarTerm = lunar.jieQi
        let lunarFestival = lunar.festivals.first
        let solarFestival = solar.festivals.first
        let otherFestival = lunar.otherFestivals.first ?? solar.otherFestivals.first

        let subtitle: String
        let subtitleKind: CalendarSubtitleKind
        if !solarTerm.isEmpty {
            subtitle = solarTerm
            subtitleKind = .solarTerm
        } else if let lunarFestival {
            subtitle = lunarFestival
            subtitleKind = .festival
        } else if let solarFestival {
            subtitle = solarFestival
            subtitleKind = .festival
        } else if let otherFestival {
            subtitle = otherFestival
            subtitleKind = .other
        } else if lunar.day == 1 {
            subtitle = "\(lunar.monthInChinese)月"
            subtitleKind = .lunar
        } else {
            subtitle = lunar.dayInChinese
            subtitleKind = .lunar
        }

        let holiday = HolidayUtil.getHolidayByYmd(
            year: solar.year,
            month: solar.month,
            day: solar.day
        )

        let monthComponents = calendar.dateComponents([.year, .month], from: currentMonth)
        let isCurrentMonth = solar.year == monthComponents.year && solar.month == monthComponents.month
        let weekday = calendar.component(.weekday, from: date)

        return CalendarDay(
            id: String(format: "%04d-%02d-%02d", solar.year, solar.month, solar.day),
            date: date,
            year: solar.year,
            month: solar.month,
            day: solar.day,
            yearText: "\(solar.year)年",
            monthText: "\(solar.month)月",
            lunarFull: "\(lunar.monthInChinese)月\(lunar.dayInChinese)",
            subtitle: subtitle,
            subtitleKind: subtitleKind,
            holidayBadge: holiday.map { $0.work ? "班" : "休" },
            holidayName: holiday?.name,
            isToday: calendar.isDateInToday(date),
            isWeekend: weekday == 1 || weekday == 7,
            isCurrentMonth: isCurrentMonth,
            weekText: "星期\(solar.weekInChinese)",
            ganzhiYear: lunar.yearInGanZhi,
            zodiac: lunar.yearShengXiao,
            ganzhiMonth: lunar.monthInGanZhi,
            ganzhiDay: lunar.dayInGanZhi,
            yi: lunar.dayYi,
            ji: lunar.dayJi
        )
    }
}

enum CalendarMenuSummary {
    static func todayText() -> (solar: String, almanac: String, lunar: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .current
        let now = Date()
        let day = CalendarDayBuilder.make(date: now, currentMonth: now, calendar: calendar)

        let almanac = "宜 \(day.yi.prefix(4).joined(separator: " ")) · 忌 \(day.ji.prefix(4).joined(separator: " "))"
        return (
            "今天 \(day.month)月\(day.day)日 \(day.weekText) · \(day.lunarFull)",
            almanac,
            day.lunarFull
        )
    }
}
