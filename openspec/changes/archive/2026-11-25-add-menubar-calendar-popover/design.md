# Design: 状态栏日历图标与月历下拉面板

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│ StatusBarRegistry                                            │
│   注册 4 个独立 NSStatusItem（CPU / MEM / 网速 / 日历图标）      │
└───────────────────────┬──────────────────────────────────────┘
                        │ activate(from view)
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ CalendarStatusBarEntry                                       │
│   makeView() → 只含 NSImageView(calendar symbol) 的 NSView     │
│   activate() → NSPopover(contentViewController: NSHosting...)  │
└───────────────────────┬──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ CalendarPopoverView (SwiftUI, darkAqua)                      │
│   深色玻璃卡片 + 顶部 NSPopover 箭头 + 1px 亮边                │
│   头部：2025年10月（大标题）      ‹   ○   ›   ⋯                │
│   网格：周日首列 + 邻月淡显 + 今日蓝框 + 农历/节日彩色标记      │
└───────────────────────┬──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ 数据层：CalendarDayBuilder.make(date:currentMonth:calendar:)  │
│   → LunarSwift（农历/节气/宜忌/干支）+ HolidayUtil（休班）      │
└──────────────────────────────────────────────────────────────┘
```

## 关键决策

1. **条目只放图标**：`makeView()` 返回一个固定 22×22 的 `NSView`，内部 `NSImageView` 用 `NSImage(systemSymbolName: "calendar")`，`symbolConfiguration` 设 `.pointSize(15)`；不显示日期文字，宽度恒定。沿用 `StatusBarRegistry` 的 `variableLength` 与 0 内缩。
2. **NSPopover**：`behavior = .transient`、`appearance = darkAqua`、`contentSize = NSSize(width: 336, height: 382)`，锚定在传入的 `NSView`；`NSApp.activate(ignoringOtherApps: true)` 后再 `show(relativeTo:of:preferredEdge: .minY)`；`popover.delegate` 持有自己避免释放。SwiftUI 根视图用 `NSVisualEffectView(.hudWindow)` 做深色玻璃底 + 16pt 圆角 + 白色 16% 描边，贴近锁定屏月历卡片。重复点击直接关闭。
3. **月历网格**：`MCalendarView(selectedDate: $selectedDate, selectedRange: nil)`；配置 `.startMonth(current - 1y)`、`.endMonth(current + 1y)`、`.firstWeekday(.sunday)`、`.locale(Locale(identifier: "zh_CN"))`、`.scrollTo(date: scrollDate)`、`.onMonthChange { visibleMonth = $0 }`、`.dayView(LunarDayView.init)`、`.monthLabel(EmptyMonthLabel.init)`、`.weekdaysView(ChineseWeekdaysView.init)`、`.monthsViewBackground(.clear)`。月份标题由面板头部统一绘制，库内标题置空。
4. **翻月**：顶部 `‹` / `›` 按钮改 `scrollDate`（用 `Calendar.date(byAdding: .month, value: ±1, to: visibleMonth)`），触发库内 `onChange(of: configData.scrollDate)` 的 `ScrollViewProxy.scrollTo`；「今天」按钮设 `scrollDate = Date()` 并把 `selectedDate` 设为今天。
5. **自定义 DayView**：实现 `DayView` 协议并覆盖 `body`（库默认会把非当月日期画成空白，这里改为 30% 淡显）；`createContent()` 返回 `VStack`：17pt 公历数字 + 10pt 农历/节气小字 + 最多 2 个彩色小圆点 + 右上角 `CalendarFlagShape` 书签；今日/选中日套 1.6pt 蓝色圆角描边。标记颜色由 `subtitleKind` 与 `holidayBadge` 推导，不使用事件数据。
6. **数据一致性**：下拉面板自己持有一个轻量 `CalendarStore`（仅用于 42 格农历数据），但日期选择状态由 `MCalendarView` 的 `selectedDate` binding 驱动；`CalendarDayBuilder.make` 是纯函数，同一天多次调用结果相同。
7. **关闭行为**：popover `.transient` 点击外部自动关闭；`deinit` 时 `popover.close()`；模块被关闭时 `isAvailable = false`，`StatusBarRegistry` 自动拆掉状态项。

## 兼容性

- `Mijick/CalendarView` 1.1.1：SwiftPM 5.7 tools、macOS 11+、零依赖，与本项目 macOS 14 / Swift 6.2.4 兼容；`@MainActor` 协议与 SwiftUI 生命周期一致。
- 不触碰 Sparkle 的 rpath 与签名流程；新增代码只在 `MacAppControlDeck` executable target 内。
- 新增第三方库需在 `THIRD_PARTY_NOTICES.md` 声明 MIT。
