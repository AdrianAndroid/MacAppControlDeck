# 提案：副屏改成 MagicMirror 风格三栏与预报表

## Why

横屏三栏虽然解决了挤压，但天气栏还是旧样式：温度/天气文字/高低温堆在一行，3 天预报的图标和温度混排，三栏的视觉重量也不一致。希望按 MagicMirror 右上角的天气模块重做，并让三栏严格等宽、头部节奏统一。

## What Changes

- 横屏三栏改为 `1fr 1fr 1fr`，栏距统一；三栏都用「kicker + 1px 分隔线」开头。
- 时钟栏：方形表盘 + `MON 23 NOV` 日期，整体在栏内居中。
- 月历栏：`CALENDAR` 头部、红色月份标题、5 行自适应网格、今日胶囊。
- 天气栏按 MagicMirror 结构：右对齐城市、湿度/降水、56px 单色图标 + 48px 温度、体感、`WEATHER FORECAST` 分隔线、5 天四列表格、更新时间与署名。
- 预报从 3 天扩到 5 天（`/api/weather` 输出前 5 天，页面取 5 条）。
- 竖屏顺序改为「时钟 → 天气（含预报）→ 月历」，压缩天气块给月历留足行高；未配置天气时回到「时钟 + 月历」两栏。
- 图标继续用内联单色 SVG，不引外部图片/CDN。
- 页面版本提升到 `2026-11-23.9`。

**非目标**：

- 不新增风力/日出字段（这一行先用湿度/降水），不改天气接口协议。
- 不引入 QWeather 图标库资源。
- 不改手机按钮面板。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：副屏三栏布局、天气栏结构与 5 天预报表。

## Impact

- 代码：`ScreenHTML.swift`、`WeatherService.swift`、`APIRouterTests.swift`。
- 用户可见：副屏横屏三栏等宽，天气栏按 MagicMirror 风格重排，预报扩到 5 天；竖屏顺序调整。
