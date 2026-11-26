# 任务：副屏主天气图标换用 Meteocons Monochrome

## 1. 资源

- [x] 1.1 vendor 28 个 Monochrome 动画 SVG
- [x] 1.2 vendor 28 个 Monochrome 静态 SVG（减少动态降级）
- [x] 1.3 新增 `Resources/Licenses/Meteocons-LICENSE.txt`
- [x] 1.4 `THIRD_PARTY_NOTICES.md` 记录来源、版本、MIT

## 2. 实现

- [x] 2.1 `ScreenHTML.iconData(named:)` 读取 `Screen/icons`，校验文件名
- [x] 2.2 `GET /screen/icons/<name>.svg` 只读路由与缓存头
- [x] 2.3 页面映射表 + `weatherHeroAsset()`
- [x] 2.4 动画版反色、静态版 `currentColor`
- [x] 2.5 未映射/失败回退 `weatherIcon()`
- [x] 2.6 reduced-motion 加载静态版，偏好变化自动重载
- [x] 2.7 删除 `.wxa-*` 自写动画与 `weatherHeroIcon()`
- [x] 2.8 `ScreenHTML.version` 提升到 `2026-11-27.14`

## 3. 验证

- [x] 3.1 单测：动画资源含 SMIL、静态资源无动画、非法文件名拒绝
- [x] 3.2 无头浏览器：动画版 `viewBox 128`、SMIL 持续推进
- [x] 3.3 无头浏览器：reduced-motion 加载静态版且可见
- [x] 3.4 无头浏览器：999/900 回退旧 24×24 图标
- [x] 3.5 小时条/5 天预报仍是旧静态图标
- [x] 3.6 `swift test --filter ScreenHTMLTests` 6 项通过
- [x] 3.7 `swift build` 通过
- [x] 3.8 覆盖安装后 `/screen/icons/clear-day.svg` 返回 200 `image/svg+xml`
- [x] 3.9 安装包后台启动，未抢焦点
