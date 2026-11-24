# Change: 统一手机面板应用按钮与快捷按钮字号

## Why

手机面板里「应用」按钮和「快捷操作」按钮的字号不一致：快捷卡片用一段自适应算法在格子内取「能放下的最大字号」，上限写死 16px，结果比应用卡片的 `--label`（11–13px）大出一截，看起来像开了老年人模式/大字号。同一屏里两区文字大小不同，视觉上没有层级依据。

## What Changes

1. 快捷卡片的默认字号改为与应用卡片同一来源：`--sc-unit: var(--label)`（不再写死 11px）。
2. 自适应拟合只缩小、不放大：`fitShortcutContent()` 的上限取「当前应用按钮 label 的实际字号」（量不到时回退 11px），仍在空间不足时继续等比缩小，保证长名称不裁切。
3. 快捷卡片的图标/名称/状态比例与应用卡片对齐：`symbol` 比例 1.45 → 1.55，`state` 由 `unit × .78` 改为 `unit - 2px`，`line-height` 1.12 → 1.15。
4. `PanelHTML.version` 递增到 `2026-11-24.1`，浏览器缓存自然失效。
5. 新增 WebKit 回归测试 `testButtonTypographyConsistency`：横屏 844×390、极窄横屏 480×320、竖屏 390×844 三种视口下断言快捷字号大于 0、不大于应用字号，且内容不裁切，并导出截图。

## Capabilities

- `remote-web-panel`：应用按钮与快捷按钮的字号遵循同一上限与同一比例规则。

## Impact

- 只改 `Sources/MacAppControlDeck/Panel/PanelHTML.swift`（内嵌 CSS/JS）与 `Tests/MacAppControlDeckTests/PanelLayoutTests.swift`。
- 不改面板服务接口、按钮数据协议、翻页/收起逻辑；无新增用户可见入口（R0 不适用）。
- 需要重新构建并固定签名覆盖安装才能看到效果。

## Non-goals

- 不改变应用卡片/快捷卡片的格子数量、翻页与左轨收起行为。
- 不调整拍摄类其它页面的字号（副屏 `/screen/` 不在本变更范围）。

## Verification

- `swift test --filter PanelLayoutTests`：4 项全绿（含新增 `testButtonTypographyConsistency`）。
- 实测字号：横屏 844×390 应用 12.09px / 快捷 12.07px；极窄横屏 480×320 11.00 / 10.98；竖屏 390×844 12.09 / 12.07。
- 截图见 `Docs/verification/panel-button-typography/`（type-landscape / type-narrow / type-portrait）。
