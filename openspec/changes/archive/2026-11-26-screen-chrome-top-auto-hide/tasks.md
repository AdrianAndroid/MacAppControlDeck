# 任务清单

- [x] 1. `.chrome` 位置从底部改为顶部，动画方向相应调整。
- [x] 2. `keepUIVisible()` 去掉触屏常驻例外，统一 5 秒自动隐藏。
- [x] 3. 保留首次进入短暂展示（400ms 后 showUI），5 秒后自动消失。
- [x] 4. WKWebView 离屏验证：初始展示、5 秒后隐藏、点击唤出、bar 位于顶部。
- [x] 5. 全量测试通过、release 构建签名、覆盖安装，线上 CSS 确认；同步 `remote-web-panel` 规格与 README。
