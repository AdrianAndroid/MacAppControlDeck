# 设计：副屏三栏与天气栏

## 布局

- 横屏 `.stage` 用 CSS Grid，`grid-template-columns: repeat(3, minmax(0, 1fr))`、`grid-template-rows: 1fr`，三列显式 `grid-row: 1`，避免自动放置把月历挤到第二行。
- 每列固定结构：kicker（11px 大写、字距 .14em）+ 1px 分隔线 + 内容；三栏 kicker 在同一基线。
- 列内分配：时钟列 `flex` 居中表盘与日期；月历列头部贴顶、网格自适应；天气列头部贴顶、内容按 MagicMirror 顺序。

## 时钟

- canvas 用 `aspect-ratio: 1/1` 保持正圆，`max-height: 100%` 防止超过列高；表盘 + 日期作为一个整体居中。

## 月历

- 月份行按 `vw` 缩放（约列宽 1/3），窄横屏不压到天气栏；网格 `1fr` 行高，5–6 行都能撑满；今日红色胶囊。

## 天气

- 头部右对齐城市；第二行湿度/降水用 `space-between`。
- 主视觉：单色 SVG 图标 9u ≈ 56px，温度 7.4u ≈ 48px（weight 200），右对齐；体感 3u。
- 预报表：`WEATHER FORECAST` + 分隔线；每行 grid `minmax(0,1fr) auto auto auto`，四列对齐；图标 3.6u ≈ 22px；高低温右对齐、低温灰色。
- 底部：更新时间 + 和风署名（保留 Attribution）。
- 未配置天气：隐藏整列，横屏回到两栏、竖屏回到时钟+月历。

## 竖屏

- 顺序时钟 → 天气 → 月历；时钟 24%，天气块压缩字号与行距，月历吃剩余高度；单元格 4vw，今日胶囊 1.55em，避免行高不足。

## 数据

- `WeatherService` 输出 `prefix(5)`；页面 `data.daily.slice(0, 5)`。
- 不新增字段；湿度取 `now.humidity`，降水取 `today.precipProbability`。
