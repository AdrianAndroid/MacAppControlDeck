# 任务：副屏视口铺满与可调内边距

## 1. 实现

- [x] 1.1 删除大屏 `#frame { inset: 2.6u }`，`#frame` 始终 `inset: 0`
- [x] 1.2 写死的 `3u` 内边距改为 `--vp-top/right/bottom/left`，默认 0
- [x] 1.3 `ScreenFrameConfig` 增四个 padding 字段（默认 0、范围 0–120、可归一化）
- [x] 1.4 `ScreenAppearanceSettings` 增四个键、发布属性与持久化
- [x] 1.5 `applyScreenFrame` 把四边 padding 写入 CSS 变量
- [x] 1.6 设置页「外观」增四个步进器与「归零」
- [x] 1.7 `ScreenHTML.version` 提升到 `2026-11-27.9`

## 2. 验证

- [x] 2.1 默认 0 时横屏四栏铺满视口（1788×855 截图）
- [x] 2.2 四边设 12px 时横屏内容整体内缩且不溢出（截图）
- [x] 2.3 竖屏 500×900 四边 12px 不溢出、倒计时仍完整（截图）
- [x] 2.4 `swift test --filter ScreenFrameConfigTests` 5 项通过
- [x] 2.5 `swift test --filter ScreenHTMLTests` 2 项通过
- [x] 2.6 `swift build` 编译通过
- [x] 2.7 截图验收使用无头 Chrome，未启动 App、未抢占焦点
