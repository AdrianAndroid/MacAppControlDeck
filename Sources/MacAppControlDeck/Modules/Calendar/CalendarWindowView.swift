import SwiftUI

struct CalendarWindowView: View {
    @ObservedObject var store: CalendarStore
    @ObservedObject var preferences: CalendarPreferences
    let onOpenSettings: () -> Void

    private var weekdaySymbols: [String] {
        preferences.weekStartsOnMonday
            ? ["一", "二", "三", "四", "五", "六", "日"]
            : ["日", "一", "二", "三", "四", "五", "六"]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            weekdayHeader
            monthGrid
            Divider()
            detailPanel
        }
        .frame(minWidth: 660, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.monthTitle)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(store.monthGanzhi)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: { store.moveMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .help("上个月")

            Button("今天") {
                store.goToday()
            }
            .buttonStyle(.borderedProminent)

            Button(action: { store.moveMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered)
            .help("下个月")
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text("周\(symbol)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(symbol == "六" || symbol == "日" ? Color.red.opacity(0.8) : Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private var monthGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 6), count: 7),
            spacing: 6
        ) {
            ForEach(store.days) { day in
                CalendarDayCell(
                    day: day,
                    isSelected: isSelected(day)
                ) {
                    store.select(day)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let day = store.selectedDay {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(day.month)月\(day.day)日")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            Text(day.weekText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Text(day.lunarFull)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("\(day.ganzhiYear)年 · \(day.zodiac)年 · \(day.ganzhiMonth)月 · \(day.ganzhiDay)日")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 18)

                    VStack(alignment: .leading, spacing: 8) {
                        almanacRow("宜", day.yi, color: .green)
                        almanacRow("忌", day.ji, color: .red)
                    }
                    .frame(maxWidth: 360, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.secondary)
                    Text(store.nextHolidayText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let holidayName = day.holidayName, let badge = day.holidayBadge {
                        Text("\(holidayName) · \(badge)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    }
                    Button("设置…", action: onOpenSettings)
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func almanacRow(_ label: String, _ items: [String], color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(color))
            Text(items.isEmpty ? "无" : items.prefix(6).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }

    private func isSelected(_ day: CalendarDay) -> Bool {
        Calendar(identifier: .gregorian).isDate(day.date, inSameDayAs: store.selectedDate)
    }
}

private struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(day.day)")
                    .font(.system(size: day.isToday ? 21 : 19, weight: day.isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(numberColor)

                Text(day.subtitle)
                    .font(.system(size: 10.5, weight: day.subtitleKind == .solarTerm ? .semibold : .regular))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(day.isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if let badge = day.holidayBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(badge == "休" ? Color.green : Color.orange))
                        .padding(4)
                }
            }
            .opacity(day.isCurrentMonth ? 1 : 0.38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.year)年\(day.month)月\(day.day)日 \(day.lunarFull)")
    }

    private var numberColor: Color {
        if day.isToday {
            return .accentColor
        }
        if day.isWeekend {
            return .red
        }
        return .primary
    }

    private var subtitleColor: Color {
        switch day.subtitleKind {
        case .solarTerm:
            return .blue
        case .festival:
            return .orange
        case .other:
            return .pink
        case .lunar:
            return .secondary
        }
    }
}
