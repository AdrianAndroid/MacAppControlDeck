# 任务：尽量扩大副屏天气图标的动画映射

## 1. 实现

- [x] 1.1 新增 `sun-hot` / `thermometer-mercury-cold` / `dust` 动画与静态资源
- [x] 1.2 映射 900 → sun-hot、901 → thermometer-mercury-cold
- [x] 1.3 503/504/505/507/508 → dust
- [x] 1.4 新增 1xx/3xx/4xx/5xx 同族兜底
- [x] 1.5 999 与无法归族 code 继续回退旧图标
- [x] 1.6 `ScreenHTML.version` 提升到 `2026-11-27.15`

## 2. 验证

- [x] 2.1 无头浏览器：901/900/503 均加载 128×128 SMIL 动画
- [x] 2.2 无头浏览器：999 仍回退 24×24 静态图标
- [x] 2.3 `swift test --filter ScreenHTMLTests` 7 项通过
- [x] 2.4 新增资源包含在 App bundle
- [x] 2.5 覆盖安装后 `/screen/icons/sun-hot.svg` 等可访问
