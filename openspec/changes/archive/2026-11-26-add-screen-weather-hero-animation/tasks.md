# 任务：副屏天气主图标轻动效

## 1. 设计

- [x] 1.1 确认只动 `#wxIcon` 主图标，小时条/预报保持静态
- [x] 1.2 定义六类图标分组与动效参数
- [x] 1.3 定义轮询去重与 reduced-motion 降级
- [x] 1.4 设计评审通过（用户确认「可以，开始开发」）

## 2. 实现

- [x] 2.1 新增 `weatherHeroIcon()`，输出带 `.wxa-*` 分组的 SVG
- [x] 2.2 添加 CSS keyframes 与 `prefers-reduced-motion` 降级
- [x] 2.3 `renderWeather()` 按 icon code 去重渲染主图标
- [x] 2.4 `clearWeather()` 重置主图标缓存
- [x] 2.5 `ScreenHTML.version` 提升，强制副屏重载

## 3. 验证

- [x] 3.1 六类天气动画截图无裁切、无抖动
- [x] 3.2 reduced-motion 下完全静止
- [x] 3.3 同一 code 连续轮询不重建 DOM
- [x] 3.4 小时条/预报 SVG 无动画 class
- [x] 3.5 1788×855 / 844×390 / 500×900 三视口检查
- [x] 3.6 `swift test --filter ScreenHTMLTests` 通过
- [x] 3.7 无头 Chrome 验收，不抢焦点
