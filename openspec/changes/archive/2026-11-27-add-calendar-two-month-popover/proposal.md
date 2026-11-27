# 提案：状态栏日历双月面板、整页翻动与节日显示开关

## Why

状态栏日历第一次点开明显卡顿：旧实现用 `MijickCalendarView` 把前后一年（约 24 个月、上千个日期格）都纳入无限滚动视图，
每次打开都要为大量日期计算农历/节气/节日。用户只需要快速看近期日期，不需要整年列表。

同时提出三个体验要求：

1. 一次显示当月 + 下月，翻页依次类推；
2. 鼠标滚轮/箭头整页翻动，不做列表内滑动；
3. 日期下方小字支持「关 / 精简 / 全显示」，默认精简。

## What Changes

- 弹窗改为自绘双月网格：一次只构建两页（约 70 个日期格），移除 Mijick 无限滚动列表。
- 面板显示「当月 + 下月」，左右箭头与鼠标滚轮按整月翻页；触控板惯性阶段不连续翻页。
- 日期下方小字新增偏好 `CalendarFestivalDisplay`：
  - `off`：不显示农历/节气/节日
  - `compact`（默认）：只显示节气与传统节日，隐藏普通农历日和“世界 xx 日”等次要条目
  - `full`：显示全部农历/节气/节日
- 弹窗底部提供「关 / 精简 / 全显示」分段开关；设置 → 万年历与弹窗 `⋯` 菜单也可切换。
- 弹窗尺寸调整为 340×552；底部增加一行“滚轮或 ← → 整页翻月”。

**非目标**：

- 不改完整万年历窗口的月历布局。
- 不删除 `CalendarDayBuilder` 的农历/宜忌数据能力。
- 不做日历日程（EventKit）集成。

## Capabilities

### Modified Capabilities

- `status-bar`：日历 popover 改为双月、整页翻动，并支持节日小字显示模式。

## Impact

- 代码：`Modules/Calendar/CalendarPopoverView.swift`（重写）、`CalendarPreferences.swift`、
  `CalendarSettingsView.swift`、`CalendarStatusBarEntry.swift`（尺寸）。
- 性能：首屏从约 24 个月/上千格降到 2 个月/约 70 格。
- 数据/权限：无新增；`calendar.festivalDisplay` 存 UserDefaults。
