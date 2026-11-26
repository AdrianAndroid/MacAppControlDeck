# 提案：修复副屏内边距被 safe-area 二次放大

## Why

副屏在 iPhone / 带刘海设备上横屏时，`env(safe-area-inset-*)` 会额外叠加到用户设置的内边距上：
设置里四边都是 0，页面仍被撑出左右约 44–50pt、底部约 20–30pt 的空白，看起来"上边贴边、左右和下面没贴边"。
用户要的是"0 就是贴边"，刘海 / 圆角留白应当可以显式用内边距补。

## What Changes

- `#frame` 的 padding 改为纯 `--vp-top/right/bottom/left`，不再自动加 safe-area。
- 控制条顶部定位从 `env(safe-area-inset-top) + 2u` 改为 `var(--vp-top) + 2u`，跟随用户设置。
- 设置页说明补充：默认 0 铺满，页面不再自动叠加刘海 / 安全区留白。
- `ScreenHTML.version` 提升到 `2026-11-27.10`，强制已打开的副屏重载新样式。

**非目标**：

- 不移除 `viewport-fit=cover`，页面仍可占满整块屏幕。
- 不改变内边距取值范围与四边独立设置。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：内边距只由 Mac 端设置决定，safe-area 不再隐式增加留白。

## Impact

- 代码：`Panel/Screen/index.html`、`UI/ScreenSettingsView.swift`、`Panel/ScreenHTML.swift`。
- 权限/数据：无，不新增配置键。
- 入口：无新增，仍为 设置 → 副屏 → 外观 → 视口内边距。
