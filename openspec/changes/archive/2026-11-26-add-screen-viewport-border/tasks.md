# 任务：副屏视口外边框

## 1. 实现

- [x] 1.1 `#frame[data-border="on"]::after` 画 1px inset 描边，不占布局
- [x] 1.2 `applyScreenFrame` 应用 `viewportBorder` → `data-border`
- [x] 1.3 `ScreenFrameConfig` 增 `viewportBorder`（默认 false）
- [x] 1.4 `ScreenAppearanceSettings` 增键与发布属性
- [x] 1.5 设置页「外观」卡片增开关
- [x] 1.6 `ScreenHTML.version` 提升到 `2026-11-27.7`

## 2. 验证

- [x] 2.1 默认关闭时页面与改动前像素一致
- [x] 2.2 打开后四边各 1px，无滚动条、无布局位移
- [x] 2.3 竖屏 / 横屏 / 三档尺寸都贴住视口
- [x] 2.4 `swift test --filter ScreenDisplay` 通过
