# 任务：设备页区分主屏/副屏，配对支持扫码免手输

## 1. 副屏登记

- [x] 1.1 `ScreenClientRecord` 模型与 User-Agent 名称解析
- [x] 1.2 `ConfigStore` 新增 `screen_clients.json`、7 天/20 条上限
- [x] 1.3 `POST /api/screen/presence`（免 token、ID 白名单、204/400）
- [x] 1.4 副屏页面生成 ID、打开/30 秒/回前台上报
- [x] 1.5 `DeckState.screenClients` 与定时刷新

## 2. 设备页

- [x] 2.1 主屏组文案、最近活动/在线点与原有撤销逻辑
- [x] 2.2 副屏组：名称、最近活动、在线点、清除记录
- [x] 2.3 说明主屏必须配对、副屏只读

## 3. 配对二维码

- [x] 3.1 配对卡展示当前 IP 一次性码二维码
- [x] 3.2 面板读取 `pair` 自动配对并 `replaceState` 清理
- [x] 3.3 二维码/URL 不含长期 token
- [x] 3.6 副屏设置与菜单提供当前 IP 副屏二维码
- [x] 3.4 `PanelHTML.version` → `2026-11-27.1`
- [x] 3.5 `ScreenHTML.version` → `2026-11-27.16`

## 4. 验证

- [x] 4.1 `ConfigStoreTests` 副屏登记持久化/firstSeen 通过
- [x] 4.2 `APIRouterTests` 登记 204、非法 ID 400 通过
- [x] 4.3 面板/副屏 HTML 内容断言通过
- [x] 4.3.1 模拟 /panel/?pair=123456：自动换 token、进入主界面、地址栏清理
- [x] 4.4 真实副屏页面打开后 `screen_clients.json` 出现 `Mac · Chrome`
- [x] 4.5 `swift build` 通过
- [x] 4.6 覆盖安装后台启动，未抢焦点
