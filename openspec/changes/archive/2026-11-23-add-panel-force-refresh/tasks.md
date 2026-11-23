# 任务：点击「已连接」强制刷新面板

## 1. 实现

- [x] 1.1 `#status` 增加 `role=button`、`tabindex`、`cursor:pointer` 与按压态
- [x] 1.2 新增 `forceRefresh()`：读 `/api/panel-version` → `location.replace` 带 `v` 与 `t`
- [x] 1.3 刷新中显示「刷新中…」并忽略重复点击
- [x] 1.4 绑定 click 与 Enter/Space 键盘事件
- [x] 1.5 `PanelHTML.version` 提升到 `2026-11-23.3`

## 2. 验证

- [x] 2.1 模拟点击后 iframe 地址变为 `/panel/?v=2026-11-23.3&t=…`
- [x] 2.2 重载后状态恢复「已连接」，时钟继续走字
- [x] 2.3 重装后 `/api/panel-version` 返回 `2026-11-23.3`
- [x] 2.4 arm64 ZIP/DMG 重打并更新校验和
