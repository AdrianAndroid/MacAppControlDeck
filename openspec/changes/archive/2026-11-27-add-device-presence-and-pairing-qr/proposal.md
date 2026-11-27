# 提案：设备页区分主屏/副屏，配对支持扫码免手输

## Why

用户不清楚主屏与副屏各自连了哪些设备，也不知道配对码是否必须。
实际规则应是：主屏能执行按钮，必须配对；副屏只读，不需要配对。
配对码本身也可以进一步变成"扫码即配对"，避免手机上手动输入 6 位数字。

## What Changes

- 「设备」页拆成两组：
  - **主屏 · 已配对（可操作）**：现有 6 位配对码换发的 token 设备，可撤销。
  - **副屏 · 只读（无需配对）**：打开 `/screen/` 的浏览器自动登记，显示设备类型、最近活动、在线点，可清除记录。
- 副屏页面每 30 秒（可见时）向 `POST /api/screen/presence` 上报本地生成的客户端 ID；服务端从 User-Agent 生成 "iPhone · Safari" 等名称，保留 7 天、最多 20 条，存 `screen_clients.json`。
- 副屏登记**不签发 token、不能执行任何操作**；接口为只读遥测性质，无鉴权。
- 配对卡新增当前 IP 二维码：内容为 `panelURL?v=<version>&pair=<6位一次性码>`；面板读取 `pair` 参数自动配对，并用 `history.replaceState` 从地址栏移除，二维码与 URL 不含长期 token。
- 副屏设置与菜单新增当前 IP 二维码，扫码直接打开 `/screen/`（免配对）并自动登记到设备页。
- `PanelHTML.version` → `2026-11-27.1`，`ScreenHTML.version` → `2026-11-27.16`。

**非目标**：

- 不取消主屏配对；执行按钮的 token 仍是硬性安全边界。
- 不把长期 token 放进 URL、二维码或日志。
- 副屏仍是公开只读页面，未登录也能看。

## Capabilities

### Modified Capabilities

- `pairing-auth`：主屏必须配对；配对二维码只携带一次性码；设备页区分两类设备。
- `lan-api`：新增无 token 的副屏在线登记端点。
- `remote-web-panel`：副屏页面负责在线登记。

## Impact

- 代码：`Model/Models.swift`、`Store/ConfigStore.swift`、`App/DeckState.swift`、`Server/APIRouter.swift`、
  `UI/SettingsView.swift`、`Panel/PanelHTML.swift`、`Panel/Screen/index.html`、`Panel/ScreenHTML.swift`。
- 数据：新增 `screen_clients.json`（0600，7 天/20 条上限）。
- 入口：无新增独立功能入口；设备页与配对卡是现有「设备」「配对手机」的扩展。
