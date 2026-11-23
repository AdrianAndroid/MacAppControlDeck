# 提案：点击「已连接」强制刷新面板

## Why

手机端面板偶尔会因为浏览器缓存、旧版本连接状态或页面长时间挂起而显示旧内容，用户只能整页关闭重开或手动改地址。让右上角的状态徽标可点击并触发一次强制刷新，是最容易被发现的自助手段。

## What Changes

- `#status` 徽标改为可点击（`role=button`、`tabindex=0`、`cursor:pointer`），支持点击与键盘 Enter/Space。
- 点击后：
  1. 徽标显示「刷新中…」并降低不透明度，防止重复触发
  2. 请求 `/api/panel-version`（`cache: no-store`）拿到最新面板版本
  3. `location.replace('/panel/?v=<最新版本>&t=<时间戳>')`，强制绕过浏览器缓存重载
- 提升 `PanelHTML.version` 到 `2026-11-23.3`。
- 竖屏/横屏都可用；不改变原有 2 秒健康轮询与退出登录流程。

**非目标**：

- 不新增设置项，不做「清空配对凭证」动作。
- 不改变 `/api/*` 协议与按钮队列语义。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：连接状态徽标新增「点击强制刷新」行为。

## Impact

- 代码：`Sources/MacAppControlDeck/Panel/PanelHTML.swift`（CSS、`#status` 属性、`forceRefresh()`、版本号）。
- 发布物：arm64 ZIP/DMG 重新生成，校验和更新。
- 权限/数据：无新增权限；刷新不清理 `deck_token`。
