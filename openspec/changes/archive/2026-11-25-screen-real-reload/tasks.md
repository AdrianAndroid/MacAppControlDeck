# 任务清单

- [x] 1. 刷新按钮改为真正的整页重载（hardReload + URL 带 rev/t 基线）。
- [x] 2. 事件轮询发现 revision 变化时触发整页重载，替换原零散 loadXxx。
- [x] 3. URL rev 作为新基线 + eventRevisionPrimed 防首次误重载与循环。
- [x] 4. 触屏设备控制条常驻（pointer:coarse 不自动隐藏）。
- [x] 5. JS 语法校验 + 离屏验收：手动刷新真的重载；设置变更触发恰好一次重载且稳定不循环。
- [x] 6. 全量测试通过，同步 remote-web-panel 主规格。
