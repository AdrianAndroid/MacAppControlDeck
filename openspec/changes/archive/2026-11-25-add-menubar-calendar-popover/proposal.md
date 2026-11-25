# Change: 状态栏日历图标与月历下拉面板

## Why

「万年历」模块在菜单栏只有一个父菜单 + 3 行纯文字（今天 / 宜忌 / 倒数日），体验和 UI 都像 demo；而完整月历只在 720×800 的独立窗口里，要点两次才能看到。用户想要的是菜单栏一个日历图标，点开就能看到成熟月历面板（LunarBar / Calendr 那种）。

## What Changes

1. 新增第四个状态项 `calendar.panel`，菜单栏**只显示一个日历图标**（SF Symbol `calendar`），不显示日期文字，宽度固定。
2. 点击该状态项弹 `NSPopover`（不是 `NSMenu`），内部 `NSHostingController` 承载 SwiftUI 月历下拉面板。
3. 下拉面板用开源库 `Mijick/CalendarView` v1.1.1 做月历网格（MIT、macOS 11+、零额外依赖）：深色玻璃卡片、顶部小箭头、大号「2025年10月」标题与 `‹ ○ ›` 控件、周日首列、邻月日期淡显；自定义 `DayView` 显示公历数字 + 农历/节气小字 + 节日/休班彩色标记与书签、今日蓝色描边；限制月份范围为当前 ±1 年，用 `scrollTo(date:)` 定位到今天。视觉参考用户提供的 macOS 锁定屏月历截图。
4. 农历/节气/宜忌/节假日数据继续复用现有 `6tail/lunar-swift`（`CalendarDayBuilder.make`），不新增第二套日历数据源。
5. 为保持截图般的纯净面板，不再占用底部详情；「打开完整万年历…」与「设置…」收进标题栏右侧的 `⋯` 更多菜单，复用 `CalendarModule.shared.open()` 与 `MenuBarController.shared.openSettings(tab: .calendar)`。
6. 设置 →「状态栏」新增该条目的开关；模块关闭时条目自动隐藏。
7. 在 `THIRD_PARTY_NOTICES.md` 增加 `Mijick/CalendarView` 的 MIT 声明。

## Capabilities

- `status-bar`（修改）：新增一个只显示图标、点击弹 `NSPopover` 的状态项形态。
- `system-cleaner`（无改动）：不触碰三个监控项。
- `desktop-pet`（无改动）。

## Impact

- `Package.swift` 新增 SwiftPM 依赖 `Mijick/CalendarView` exact 1.1.1；`Package.resolved` 更新。
- 新增 `Sources/MacAppControlDeck/Modules/Calendar/CalendarStatusBarEntry.swift`（图标条目 + popover 控制器）。
- 新增 `Sources/MacAppControlDeck/Modules/Calendar/CalendarPopoverView.swift`（SwiftUI 下拉面板，含自定义 DayView / MonthLabel / WeekdaysView）。
- `CalendarModule.swift`：`start()` 时注册状态栏条目，`stop()` 时无需额外处理（公共注册表按 `isAvailable` 自动隐藏）。
- `THIRD_PARTY_NOTICES.md`：新增 MIT 声明。
- 用户可见：菜单栏多一个日历图标；点开出现月历下拉；设置里多一个开关。

## Non-goals

- **不读日程**：彩色小标记与书签只由农历/节气/节日/休班数据驱动，不读取 EventKit、不申请日历权限、不代表用户私人日程。
- 不改现有三个 CPU / MEM / 网速状态项。
- 不重做 `CalendarWindowView` 独立窗口；下拉与窗口共用 `CalendarDayBuilder` 数据层，但面板 UI 独立实现。
- 不引入 LunarBarKit（要求 macOS 26 / Swift 6.4，与本项目 macOS 14 / Swift 6.2.4 不兼容）。

## Design Trade-offs

- `Mijick/CalendarView` 是垂直滚动多月视图而非单月翻页：在 popover 里用 `scrollTo(date:)` 定位今天，翻月按钮通过驱动 `scrollDate` 实现；限制 ±1 年避免生成 10 年 5000+ 格子。
- 用 `NSPopover` 而非 `NSMenu` 嵌网格：日历需要持续交互（翻月、选日、面板外点击关闭），`NSMenu` 的事件处理不适合。
