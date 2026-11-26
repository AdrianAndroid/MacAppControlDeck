# 任务：修复副屏内边距被 safe-area 二次放大

## 1. 实现

- [x] 1.1 `#frame` padding 改为纯 `--vp-*`，移除 `env(safe-area-inset-*)`
- [x] 1.2 控制条 `top` 改为 `var(--vp-top) + 2u`
- [x] 1.3 设置页说明补充「不再自动叠加安全区留白」
- [x] 1.4 `ScreenHTML.version` 提升到 `2026-11-27.10`

## 2. 验证

- [x] 2.1 默认 0 时横屏 / 竖屏内容均贴住视口（无头 Chrome 截图）
- [x] 2.2 四边 12px 时仍按设置内缩，不溢出
- [x] 2.3 `swift build` 通过
- [x] 2.4 `swift test --filter ScreenHTMLTests` 通过
- [x] 2.5 覆盖安装后 `/screen/` 返回 `2026-11-27.10`，`/api/screen/frame` 四边 padding 为 0
- [x] 2.6 全流程无头 / 后台执行，未抢焦点
