# 提案：尽量扩大副屏天气图标的动画映射

## Why

用户遇到"天气冷"（和风 code 901）时主图标退回静态细线图标，观感与已替换的 Meteocons 动画不一致。
当前映射只覆盖常规晴雨雪雾，`900/901` 和少数沙尘 code 仍走回退；和风未来新增的同族 code 也会落回静态。

## What Changes

- `900 热` → Meteocons `sun-hot`（动画）
- `901 冷` → Meteocons `thermometer-mercury-cold`（动画）
- `503/504/505/507/508` → `dust`（替代原 `wind-dust`）
- 新增同族兜底：未列出的 1xx → clear、3xx → rain、4xx → snow、5xx → fog（按 150/350 分日夜）
- 只有 `999 未知` 以及无法归族的 code 继续回退旧静态图标（无天气语义可映射）
- `ScreenHTML.version` 提升到 `2026-11-27.15`

**非目标**：

- 不为 999 编造天气图标。
- 不改变小图标策略（Phase A 仅主图标）。
- 不调整 Meteocons 图标几何或动画。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：主图标映射覆盖冷/热与沙尘，并为未知同族 code 提供动画兜底。

## Impact

- 代码：`Panel/Screen/index.html`（映射表与兜底）、`Panel/Screen/icons/`（新增 3 组动画 + 3 个静态）。
- 体积：+约 17 KB。
- 入口/权限/数据：无变化。
