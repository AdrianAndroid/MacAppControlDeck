import AppKit
import SwiftUI
import MijickCalendarView

/// 状态栏日历图标点开后的月历下拉面板。
/// 视觉复刻深色玻璃月历卡片：大号月份标题、周日首列、淡显邻月日期、
/// 今日蓝色描边、农历/节气小字与「节日/休班」彩色标记。
/// 网格由 Mijick/CalendarView 提供，数据仍来自现有 CalendarDayBuilder（lunar-swift + HolidayUtil）。
@MainActor
struct CalendarPopoverView: View {
    let onOpenFull: () -> Void
    let onOpenSettings: () -> Void

    @State private var selectedDate: Date? = Date()
    @State private var scrollDate: Date? = Date()
    @State private var visibleMonth: Date = Date()
    /// MCalendarView 的 scrollDate 在 init 时固化；翻月靠重建视图触发新的 scrollTo。
    @State private var generation = 0

    private static let panelWidth: CGFloat = 336
    private static let panelHeight: CGFloat = 382

    var body: some View {
        ZStack {
            GlassCalendarBackground()

            VStack(spacing: 0) {
                header
                calendarGrid
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .frame(width: Self.panelWidth, height: Self.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text(monthTitle(visibleMonth))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 16, height: 20)
                }
                .buttonStyle(.plain)
                .help("上个月")

                Button {
                    let now = Date()
                    selectedDate = now
                    visibleMonth = now
                    scrollDate = now
                    generation += 1
                } label: {
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 1.6)
                        .frame(width: 15, height: 15)
                }
                .buttonStyle(.plain)
                .help("回到今天")

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 16, height: 20)
                }
                .buttonStyle(.plain)
                .help("下个月")

                Menu {
                    Button("打开完整万年历…") { onOpenFull() }
                    Button("设置…") { onOpenSettings() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 14, height: 20)
                }
                .menuStyle(.borderlessButton)
                .help("更多")
            }
        }
        .padding(.bottom, 10)
    }

    private func moveMonth(by offset: Int) {
        guard let target = Self.calendar.date(byAdding: .month, value: offset, to: visibleMonth) else { return }
        visibleMonth = target
        scrollDate = target
        generation += 1
    }

    // MARK: - Grid

    private var calendarGrid: some View {
        MCalendarView(
            selectedDate: $selectedDate,
            selectedRange: nil,
            configBuilder: { config in
                config
                    .locale(Locale(identifier: "zh_CN"))
                    .firstWeekday(.sunday)
                    .startMonth(Self.calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date())
                    .endMonth(Self.calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date())
                    .scrollTo(date: scrollDate)
                    .onMonthChange { month in visibleMonth = month }
                    .monthsTopPadding(0)
                    .monthsBottomPadding(0)
                    .monthsSpacing(0)
                    .monthLabelToDaysDistance(0)
                    .daysVerticalSpacing(3)
                    .daysHorizontalSpacing(0)
                    .monthsViewBackground(.clear)
                    .weekdaysView { ChineseWeekdaysView() }
                    .monthLabel { date in EmptyMonthLabel(month: date) }
                    .dayView { date, isCurrentMonth, dateBinding, rangeBinding in
                        LunarDayView(date: date,
                                     isCurrentMonth: isCurrentMonth,
                                     selectedDate: dateBinding,
                                     selectedRange: rangeBinding)
                    }
            })
            .id(generation)
            .frame(height: 300)
            .clipped()
    }

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.timeZone = .current
        return value
    }()

    private func monthTitle(_ date: Date) -> String {
        let components = Self.calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }
}

// MARK: - 深色玻璃背景

struct GlassCalendarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.appearance = NSAppearance(named: .darkAqua)
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - 自定义日期格：公历 + 农历/节气 + 今日描边 + 节日/休班标记

@MainActor
struct LunarDayView: DayView {
    let date: Date
    let isCurrentMonth: Bool
    var selectedDate: Binding<Date?>?
    var selectedRange: Binding<MDateRange?>?

    /// 覆盖库默认实现：库会把非当月日期画成空白，这里改为淡显，贴合截图。
    var body: some View {
        createContent()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { onSelection() }
    }

    func createContent() -> AnyView {
        let day = CalendarDayBuilder.make(date: date, currentMonth: date, calendar: Self.calendar)
        let isSelected = selectedDate?.wrappedValue
            .map { Self.calendar.isDate($0, inSameDayAs: date) } ?? false
        let showRing = day.isToday || isSelected
        let opacity: Double = isCurrentMonth ? 1 : 0.3

        return AnyView(
            VStack(spacing: 1) {
                ZStack(alignment: .topTrailing) {
                    Text("\(day.day)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(opacity))
                        .frame(maxWidth: .infinity, alignment: .center)

                    if let flag = Self.flagColor(for: day) {
                        CalendarFlagShape()
                            .fill(flag.opacity(opacity))
                            .frame(width: 6, height: 11)
                            .offset(x: 5, y: -1)
                    }
                }
                .frame(height: 21)

                Text(day.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Self.subtitleColor(for: day).opacity(opacity))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(height: 13)

                HStack(spacing: 2) {
                    ForEach(Array(Self.markerColors(for: day).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color.opacity(opacity))
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if showRing {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.blue, lineWidth: 1.6)
                        .padding(1)
                }
            }
        )
    }

    private static func flagColor(for day: CalendarDay) -> Color? {
        if let badge = day.holidayBadge { return badge == "休" ? Color.cyan : Color.orange }
        if day.subtitleKind == .festival { return Color.cyan }
        return nil
    }

    private static func subtitleColor(for day: CalendarDay) -> Color {
        switch day.subtitleKind {
        case .solarTerm: return .green
        case .festival: return .cyan
        case .other: return .orange
        default: return Color.white.opacity(0.62)
        }
    }

    /// 彩色小标记只代表农历/节气/休班数据，不读取 EventKit、不代表用户日程。
    private static func markerColors(for day: CalendarDay) -> [Color] {
        var result: [Color] = []
        if day.subtitleKind == .solarTerm { result.append(.green) }
        if day.subtitleKind == .festival { result.append(.cyan) }
        if day.holidayBadge != nil { result.append(.orange) }
        return Array(result.prefix(2))
    }

    private static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.timeZone = .current
        return value
    }()
}

/// 日历格右上角的小旗标，形似截图中的事件书签。
struct CalendarFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bodyHeight = rect.height * 0.7
        path.addRoundedRect(in: CGRect(x: 0, y: 0, width: rect.width, height: bodyHeight),
                            cornerSize: CGSize(width: 1.5, height: 1.5),
                            style: .circular)
        path.move(to: CGPoint(x: 0, y: bodyHeight - 0.5))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: bodyHeight - 0.5))
        path.closeSubpath()
        return path
    }
}

// MARK: - 空月份标题（标题已由面板头部统一绘制）

@MainActor
struct EmptyMonthLabel: MonthLabel {
    let month: Date

    func createContent() -> AnyView { AnyView(EmptyView()) }
}

// MARK: - 中文化周标签（周日首列）

@MainActor
struct ChineseWeekdaysView: WeekdaysView {
    func createWeekdayLabel(_ weekday: MWeekday) -> AnyWeekdayLabel {
        ChineseWeekdayLabel(weekday: weekday).erased()
    }
}

@MainActor
struct ChineseWeekdayLabel: WeekdayLabel {
    let weekday: MWeekday

    func createContent() -> AnyView {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let index = max(0, min(6, weekday.rawValue - 1))
        return AnyView(
            Text(symbols[index])
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(index == 0 || index == 6 ? 0.72 : 0.5))
        )
    }
}
