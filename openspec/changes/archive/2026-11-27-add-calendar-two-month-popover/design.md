# 设计：状态栏日历双月面板、整页翻动与节日显示开关

## 1. 性能

旧实现：

```swift
MCalendarView(...)
    .startMonth(-1 年)
    .endMonth(+1 年)
```

无限滚动视图需要为范围内容准备大量月份；每次打开都会触发大量
`CalendarDayBuilder.make`（`Lunar.fromDate` + 节假日查询），这是首次打开卡顿的主因。

新实现：

- 自绘两页 `CalendarMonthData`，每页 5–6 行 × 7 列，共约 70 个 `CalendarDay`。
- 页面数据只在打开、翻页、回到今天时重建；切换节日模式只重绘文本，不重新计算农历。
- 不再 import `MijickCalendarView`，并移除 `Package.swift` 中不再使用的 CalendarView 依赖；popover 内没有滚动容器。

## 2. 双月与整页翻动

- `pageStart` 表示第一页月份；面板固定显示 `pageStart` 与 `pageStart + 1 月`。
- `←` / `→`、回到今天、滚轮都调用 `movePage(by:)`，一次换一整页，不滚动内容。
- 滚轮监听挂在 popover 窗口上：
  - 触控板 `.began` 只翻一页，后续 `.changed` 与惯性 `momentumPhase` 被消费，不连翻；
  - 鼠标滚轮（phase 为空）按 0.32 秒节流翻页。
- 月网格按实际周数（5 或 6 行）生成，避免为凑 6 行重复下个月日期。

## 3. 节日显示模式

`CalendarFestivalDisplay`：

| 模式 | 显示 |
| --- | --- |
| `off` | 日期数字与休/班书签；不显示日期下方小字 |
| `compact`（默认） | 只显示节气、传统/公历节日；隐藏普通农历日和 `other`（世界 xx 日等） |
| `full` | 显示原 `CalendarDay.subtitle` 全部内容 |

- 偏好存 `calendar.festivalDisplay`，旧用户没有值时回落到 `compact`。
- 弹窗底部提供「节日：关 / 精简 / 全显示」分段控件；设置 → 万年历的「显示」卡片与弹窗 `⋯` 菜单也可切换。
- 日期格高度固定，切换模式不会让网格跳动。

## 4. 兼容

- 保留周日起始（与现有 popover 视觉一致）。
- 保留农历/节气/节日数据、休班书签、今日/选中蓝框、点日期选中。
- 完整万年历窗口与 `CalendarDayBuilder` 不变。

## 5. 验证

- 离屏渲染双月页面：11 月 5 行、12 月 5 行，标题为「2026年11月 – 12月」。
- `compact` 下只保留万圣节、立冬、小雪、大雪、冬至、平安夜、圣诞节等，不显示“世界 xx 日”。
- `swift build` 通过；安装后真机点开确认首屏速度、滚轮/箭头翻页与设置切换。
