import AppKit
import SwiftUI

/// 状态栏日历图标点开后的双月下拉面板。
/// 一次渲染“当月 + 下月”两页，翻页按整月推进；不创建无限滚动列表。
@MainActor
struct CalendarPopoverView: View {
    let onOpenFull: () -> Void
    let onOpenSettings: () -> Void

    @ObservedObject private var preferences = CalendarPreferences.shared
    @State private var selectedDate: Date? = Date()
    @State private var pageStart: Date
    @State private var page: CalendarPageData
    @State private var lastPageTurn = Date.distantPast

    static let panelSize = CGSize(width: 340, height: 552)
    private static let cornerRadius: CGFloat = 14

    init(onOpenFull: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onOpenFull = onOpenFull
        self.onOpenSettings = onOpenSettings
        let start = Self.startOfMonth(Date())
        _pageStart = State(initialValue: start)
        _page = State(initialValue: Self.makePage(startMonth: start))
    }

    var body: some View {
        ZStack {
            GlassCalendarBackground()
            Color.black.opacity(0.55)

            VStack(spacing: 0) {
                header
                monthsView
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
        .background(ScrollWheelMonitor { delta in
            handleScroll(delta)
        })
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text(pageTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                Button {
                    movePage(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 16, height: 20)
                }
                .buttonStyle(.plain)
                .help("上一页")

                Button {
                    let now = Date()
                    selectedDate = now
                    pageStart = Self.startOfMonth(now)
                    page = Self.makePage(startMonth: pageStart)
                } label: {
                    Text("今天")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 9)
                        .frame(height: 20)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("回到今天")

                Button {
                    movePage(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 16, height: 20)
                }
                .buttonStyle(.plain)
                .help("下一页")
            }
        }
        .padding(.bottom, 8)
    }

    private var pageTitle: String {
        let second = Self.calendar.date(byAdding: .month, value: 1, to: pageStart) ?? pageStart
        let first = Self.calendar.dateComponents([.year, .month], from: pageStart)
        let next = Self.calendar.dateComponents([.year, .month], from: second)
        if first.year == next.year {
            return "\(first.year ?? 0)年\(first.month ?? 0)月 – \(next.month ?? 0)月"
        }
        return "\(first.year ?? 0)年\(first.month ?? 0)月 – \(next.year ?? 0)年\(next.month ?? 0)月"
    }

    private func movePage(by offset: Int) {
        guard let target = Self.calendar.date(byAdding: .month, value: offset, to: pageStart) else { return }
        pageStart = Self.startOfMonth(target)
        page = Self.makePage(startMonth: pageStart)
    }

    private func handleScroll(_ delta: CGFloat) {
        guard abs(delta) > 0.5 else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPageTurn) > 0.32 else { return }
        lastPageTurn = now
        movePage(by: delta > 0 ? -1 : 1)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Text("节日小字")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 1) {
                ForEach(CalendarFestivalDisplay.allCases) { mode in
                    Button {
                        preferences.festivalDisplay = mode
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(preferences.festivalDisplay == mode ? 0.98 : 0.55))
                            .padding(.horizontal, 8)
                            .frame(height: 18)
                            .background {
                                if preferences.festivalDisplay == mode {
                                    Capsule().fill(Color.white.opacity(0.2))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.07)))

            Spacer(minLength: 4)

            Button("完整万年历") { onOpenFull() }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.62))

            Button("设置") { onOpenSettings() }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    // MARK: - Months

    private var monthsView: some View {
        VStack(spacing: 6) {
            ForEach(page.months) { month in
                monthSection(month)
            }
        }
    }

    private func monthSection(_ month: CalendarMonthData) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(month.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(month.weekdays, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(symbol == "日" || symbol == "六" ? 0.7 : 0.45))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 14)

            VStack(spacing: 0) {
                ForEach(Array(month.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(row) { cell in
                            dayCell(cell)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ cell: CalendarDayCell) -> some View {
        let day = cell.day
        let selected = selectedDate.map { Self.calendar.isDate($0, inSameDayAs: day.date) } ?? false
        let isToday = day.isToday
        let opacity = cell.isCurrentMonth ? 1.0 : 0.28
        let subtitle = subtitleText(for: day)

        return VStack(spacing: 1) {
            Text("\(day.day)")
                .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(opacity))
                .overlay(alignment: .topTrailing) {
                    if let flag = Self.flagColor(for: day) {
                        CalendarFlagShape()
                            .fill(flag.opacity(cell.isCurrentMonth ? 0.95 : 0.35))
                            .frame(width: 4, height: 6.5)
                            .offset(x: 3.5, y: -1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 18)

            subtitleLabel(day: day, text: subtitle, opacity: opacity)
                .frame(height: 13)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 33)
        .background {
            if isToday || selected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(isToday ? 0.2 : 0.09))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(isToday ? 0.9 : 0.45), lineWidth: 1.2)
                    }
                    .padding(1)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedDate = day.date }
    }

    @ViewBuilder
    private func subtitleLabel(day: CalendarDay, text: String, opacity: Double) -> some View {
        if text.isEmpty {
            Color.clear
        } else if day.subtitleKind == .lunar {
            Text(text)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5 * opacity))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        } else {
            let tint = Self.subtitleColor(for: day)
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint.opacity(opacity))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 3.5)
                .frame(height: 12.5)
                .background(Capsule().fill(tint.opacity(0.16 * opacity)))
        }
    }

    private func subtitleText(for day: CalendarDay) -> String {
        switch preferences.festivalDisplay {
        case .off:
            return ""
        case .compact:
            return day.subtitleKind == .solarTerm || day.subtitleKind == .festival ? day.subtitle : ""
        case .full:
            return day.subtitle
        }
    }

    /// 法定节假日与节日都会在日期右上角挂一个小书签；位置贴着数字，不会被今日描边盖住。
    private static func flagColor(for day: CalendarDay) -> Color? {
        if let badge = day.holidayBadge { return badge == "休" ? Color.cyan : Color.orange }
        if day.subtitleKind == .festival { return Color.cyan }
        return nil
    }

    private static func subtitleColor(for day: CalendarDay) -> Color {
        switch day.subtitleKind {
        case .solarTerm: return Color(red: 0.55, green: 0.98, blue: 0.65)
        case .festival: return Color(red: 0.5, green: 0.86, blue: 1.0)
        case .other: return Color(red: 1.0, green: 0.76, blue: 0.45)
        default: return Color.white.opacity(0.82)
        }
    }

    // MARK: - Page data

    fileprivate struct CalendarPageData {
        let startMonth: Date
        let months: [CalendarMonthData]
    }

    fileprivate struct CalendarMonthData: Identifiable {
        let month: Date
        let title: String
        let weekdays: [String]
        let rows: [[CalendarDayCell]]

        var id: String { "\(month.timeIntervalSince1970)" }
    }

    fileprivate struct CalendarDayCell: Identifiable {
        let id: String
        let day: CalendarDay
        let isCurrentMonth: Bool
    }

    private static let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.timeZone = .current
        return value
    }()

    private static let weekdays = ["日", "一", "二", "三", "四", "五", "六"]

    private static func startOfMonth(_ date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    private static func makePage(startMonth: Date) -> CalendarPageData {
        let months = (0...1).compactMap { offset -> CalendarMonthData? in
            guard let month = calendar.date(byAdding: .month, value: offset, to: startMonth) else { return nil }
            let first = startOfMonth(month)
            let weekday = calendar.component(.weekday, from: first) // 1 = 星期日
            let leading = weekday - 1
            guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: first) else { return nil }
            let monthParts = calendar.dateComponents([.year, .month], from: first)

            let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
            let rowCount = Int(ceil(Double(leading + dayCount) / 7.0))
            var rows: [[CalendarDayCell]] = []
            for row in 0..<rowCount {
                var cells: [CalendarDayCell] = []
                for column in 0..<7 {
                    let index = row * 7 + column
                    guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { continue }
                    let day = CalendarDayBuilder.make(date: date, currentMonth: first, calendar: calendar)
                    let parts = calendar.dateComponents([.year, .month], from: date)
                    let isCurrent = parts.year == monthParts.year && parts.month == monthParts.month
                    cells.append(CalendarDayCell(id: "\(monthParts.year ?? 0)-\(monthParts.month ?? 0)-\(index)",
                                                 day: day,
                                                 isCurrentMonth: isCurrent))
                }
                rows.append(cells)
            }
            return CalendarMonthData(month: first,
                                     title: "\(monthParts.month ?? 0)月",
                                     weekdays: weekdays,
                                     rows: rows)
        }
        return CalendarPageData(startMonth: startMonth, months: months)
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
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - 鼠标滚轮整页翻动（不滚动内容）

private struct ScrollWheelMonitor: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView { MonitorView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorView)?.onScroll = onScroll
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard let window else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard event.window === window else { return event }
                // 触控板惯性阶段不再连续翻页；一次手势只翻一页。
                guard event.momentumPhase.isEmpty else { return nil }
                if event.phase == .began || event.phase.isEmpty {
                    self?.onScroll?(event.scrollingDeltaY)
                }
                return nil
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil { removeMonitor() }
            super.viewWillMove(toWindow: newWindow)
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
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
