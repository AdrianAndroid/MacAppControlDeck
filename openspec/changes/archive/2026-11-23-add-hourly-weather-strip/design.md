# 设计：小时预报条

## 数据

- `QWeatherClient.fetchAll` 并行请求 current、daily、hourly；hourly 用 `try?`，失败返回 nil，不影响主天气。
- `WeatherParsing.parseHourly` 读取 `hours[]` 的 `forecastTime`、`condition.text/code`、`temperature.value`，按时间排序。
- `WeatherHourDTO { time, temp, icon, text }`；`WeatherPayload.hourly` 与 `WeatherEnvelope.hourly` 可选，最多 8 条。
- `WeatherService` 缓存与单飞逻辑不变，payload 带 hourly；浏览器仍每 30 秒轮询。

## 页面

- DOM：`wx-now`（体感）之后、`wx-block`（5 天表）之前加 `#wxHours`。
- JS：第一格用 `now` 显示「现在」，再取 `hourly.slice(0, 4)`；`formatHour` 把 UTC 时间按 `macOffsetMinutes` 转成 Mac 小时（“18时”）。
- 渲染：5 格等分，每格两行（时间 / 图标+温度）；无 hourly 时设置 `hidden`。
- CSS：`grid-template-columns: repeat(5, minmax(0,1fr))`；上边框与 1.2u 间距分隔。

## 高度

- 新增约 30px；`@media (max-height: 430px)` 压缩天气主视觉（图标 7.6u、温度 6.6u）和预报行（图标 3u、行距 .4u），保证 5 天表与更新时间仍可见。
- 竖屏时钟 24% → 20%，天气块压缩（图标 7u、温度 5.8u、行距 .3u），月历 5 行不重叠。

## 取舍

- 5 格固定（现在 + 4 小时）；宽屏不增加到 8 格，避免两套布局。
- 不做横向滚动，保持常亮屏一眼可读。
