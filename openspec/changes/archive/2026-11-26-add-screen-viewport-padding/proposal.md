# 提案：副屏视口铺满与可调内边距

## Why

副屏在大屏（≥640×520）下用 `#frame { inset: 2.6u }` 再把四边各留 `3u` 内边距，
两层留白叠加后内容明显缩在视口中间，加上走查外边框时"没填满视口"的观感尤其明显。
固定留白也无法适配不同手机安全区与个人审美，需要能在 Mac 端按上 / 右 / 下 / 左单独调节。

## What Changes

- 去掉大屏下的 `#frame { inset: 2.6u }` 浮动边框，`#frame` 始终 `inset: 0`。
- 去掉写死的 `3u` 内边距，改为四边 CSS 变量 `--vp-top/right/bottom/left`，默认 `0px`（内容铺满视口）。
- `ScreenFrameConfig` 新增 `paddingTop/paddingRight/paddingBottom/paddingLeft`（px，0–120，默认 0），
  由 `/api/screen/frame` 下发，副屏写入上述变量。
- 设置 → 副屏 → 外观新增「视口内边距」四个步进器与「归零」按钮。
- `ScreenHTML.version` 提升到 `2026-11-27.9`。

**非目标**：

- 不改动 `.stage` 内部三栏比例、间距与卡片自身内边距。
- 不改变视口外边框（走查）的 1px 绘制方式与命中规则。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：副屏默认铺满视口，视口内边距可在 Mac 端四边独立调节。

## Impact

- 代码：`Panel/Screen/index.html`（CSS / `applyScreenFrame`）、
  `Modules/RemoteControl/ScreenAppearance.swift`、`UI/ScreenSettingsView.swift`、
  `Panel/ScreenHTML.swift`（版本号）。
- 权限/数据：无；内边距存 `UserDefaults`，键 `screen.frame.paddingTop` 等四个。
- 入口：设置 → 副屏 → 外观；默认 0 铺满，不新增独立功能入口。
