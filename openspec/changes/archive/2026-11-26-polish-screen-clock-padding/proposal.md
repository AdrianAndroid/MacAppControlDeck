# Change: 副屏时钟去掉底部日期行，圆盘四周恒定留白

## Why

副屏时钟卡的表盘几乎贴着卡片边框（刻度距边框只有 ~3%），左上角显得"顶边"；底部还压着一行 `THU 26 NOV`，而月历栏已经把当天标红，信息重复，横屏看着挤、竖屏（时钟区仅 20% 高）还白占一行。

## What Changes

1. 删除时钟卡底部日期行：HTML（`.date-line`）、CSS、以及 `#dateLine` 的三处 JS 引用全部移除。
2. 表盘几何改为「短边一半 − 恒定留白」：`R = min(w, h)/2 − 2.4u`（`--u` 换算成像素），任何宽高比下圆盘四周都是同一个边距；canvas 改为铺满主区并居中，不再用 `aspect-ratio` 挤占空间。
3. 时钟卡去掉自己的内边距（`padding: 0`），四周留白统一由表盘 margin 决定，横屏四卡边框对齐、圆盘四边等距。
4. `ScreenHTML.version` → `2026-11-26.1`，副屏页面按版本自检刷新。

## Capabilities

- `remote-web-panel`（修改）：副屏时钟卡的排版约束。

## Impact

- 只改 `Panel/Screen/index.html` 与 `Panel/ScreenHTML.swift`（版本号）。
- 不影响月历、天气、倒计时、宠物卡片与 `/api/*` 契约。

## Non-goals

- 不动时钟指针样式、刻度密度与配色。
- 不做时钟卡头部标题（之前讨论过，本轮不做）。
