# 提案：横屏时钟改为鲜艳红色

## Why

横屏时钟当前使用与说明文字相近的灰紫色，在深色面板上不够醒目。用户希望它像告警/强调信息一样醒目，指定使用鲜艳红色。

## What Changes

- 时钟颜色改为鲜艳红 `#ff3b30`，加粗（700）、字号略增，并加同色柔光，深色背景上更清晰。
- 新增 `--clock` / `--clock-glow` 变量，便于后续统一调整。
- 提升 `PanelHTML.version` 到 `2026-11-23.2`，已打开的面板自动刷新。
- 竖屏仍隐藏时钟；横屏标题栏在 568×320 及以上尺寸保持不溢出。

**非目标**：

- 不改布局结构、不新增设置项、不做颜色自定义。
- 不改时钟格式与刷新频率。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：横屏系统时钟的视觉要求改为鲜艳红色强调。

## Impact

- 代码：`Sources/MacAppControlDeck/Panel/PanelHTML.swift`（CSS 变量、时钟样式、版本号）。
- 发布物：arm64 ZIP/DMG 重新生成，校验和更新。
