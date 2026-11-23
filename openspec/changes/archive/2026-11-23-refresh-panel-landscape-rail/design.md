# 设计：面板横屏三栏

## 结构

- `body` 在横屏下改为 `grid-template-columns: var(--left-rail) minmax(0,1fr)`；`header` 作为第一列竖轨，`#main` 作为第二列。
- 竖轨：`h1`（自动换行，`word-break:keep-all`）、`#clock`（日期/星期/时间三行）、底部 `#fullscreen` 与 `#status`（`margin-top:auto` 顶到底部）。
- `#main` 保持 row：`#appsZone | #shortcutsZone`；快速区宽度仍由 4 行方形按钮反推，额外加 26px 竖排标题列与间距。
- `.zone` 在横屏使用 grid：`26px + 1fr` 两列、`1fr + auto` 两行；标题竖排在左列跨两行，pages 在右列第一行，dots 在右列第二行。
- 竖屏不进入这些规则，保持原有 flex 布局。

## 每页容量

- 横屏：`appCols = innerWidth < 700 ? 3 : 4`，`appRows = 12 / appCols`，固定 12 个/页。
- 快捷：2×4 = 8/页。
- 竖屏：应用 2 列、行数按高度计算；快捷 4×2。
- 翻页：沿用 scroll-snap；页点 + `1/N`；`1/N` 仅横屏显示，竖屏保持原样。

## 时钟

- `tickClock` 输出三个 span：`clock-date`（YYYY/MM/DD）、`clock-weekday`（星期X）、`clock-time`（HH:mm:ss）。
- 横屏三行显示，时间红色加粗；竖屏 `#clock` 仍为 `display:none`。
- 日期使用斜杠格式，避免 `2026年11月23日` 在 86–108px 竖轨内换行裂开。

## 适配

- 竖轨宽度 `clamp(86px, 11vw, 108px)`；标题字号 `clamp(10px, 1.4vw, 12px)`，极窄横屏不溢出。
- <700px 横屏应用改 3×4；极矮横屏沿用 `max-height:360px` 的字号/间距压缩。
- 竖屏、配对页、强制刷新、全屏、按钮状态逻辑不变。
