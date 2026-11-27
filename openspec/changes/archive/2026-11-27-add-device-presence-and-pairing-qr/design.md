# 设计：设备页区分主屏/副屏，配对支持扫码免手输

## 1. 两类连接

| | 主屏面板 | 副屏 |
| --- | --- | --- |
| 入口 | `/panel/` | `/screen/` |
| 能否执行 | 能（启动应用、按键、命令） | 不能，只读 |
| 鉴权 | 6 位一次性配对码 → token | 无 token |
| 设备页 | 已配对设备，最近活动/在线点，可撤销 | 在线登记，最近活动/在线点，可清除 |
| 存储 | `devices.json` | `screen_clients.json` |

## 2. 副屏在线登记

页面：

```js
// localStorage 中生成 screen-<时间>-<随机>，只用于识别同一浏览器
fetch('/api/screen/presence', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ id: screenClientId() })
});
```

- 打开页面立即上报；每 30 秒且 `document.visibilityState === 'visible'` 时补报；回到前台再报。
- 服务端不存 IP，只存 ID、名称、首次/最近时间；名称由 User-Agent 推导（iPhone/iPad/Android/Mac/Windows + Safari/Chrome/Edge/Firefox）。
- 7 天未活动自动清理；最多 20 条；写入 `screen_clients.json`（0600）。
- 设备页每 2 秒从内存快照刷新（与权限状态轮询同频）；最近 90 秒内有上报显示绿点。

## 3. 配对二维码

- 设置 → 电脑控制 → 服务生成配对码后，旁边展示当前 IP 二维码：
  `http://<stable-host>.local:<port>/panel/?v=<PanelHTML.version>&pair=<code>`
- 面板 `init()`：
  - 已有 token → 直接进主界面。
  - 无 token → 显示配对页；若 URL 有 6 位 `pair`，填入并调用 `doPair()`，成功后写入 localStorage token，再进入主界面。
  - 立即 `history.replaceState` 把 `pair` 从地址栏移除。
- 二维码只包含一次性码，不包含长期 token；码 2 分钟有效、错 3 次作废。
- 设置 → 副屏地址、菜单「显示副屏二维码…」同样提供当前 IP 二维码；副屏免配对，扫码直接打开并自动登记。
- 需要手动输入时原 6 位输入框保持不变。

## 4. 设备页

- 主屏组复用 `state.devices` 与撤销逻辑；`lastSeenAt` 由每次带 token 请求更新（最多 2 分钟落盘一次），设备页显示在线点与「最近活动」。
- 副屏组使用新的 `state.screenClients`；名称、`Text(lastSeenAt, style: .relative)`、在线点。
- 「清除记录」只删登记；页面若仍打开会在下一次心跳重新出现，文案已说明。

## 5. 安全与隐私

- `/api/screen/presence` 是唯一新增的免 token POST：只写展示用登记，不能读按钮、不能执行、不能撤销设备。
- `id` 白名单 `^[A-Za-z0-9_-]{8,64}$`，请求体上限沿用 4 KB，记录有上限。
- 不记录 IP、不记录完整 User-Agent，只记录推导后的设备/浏览器名称。
- 长期 token 仍只存 Mac `devices.json` 与手机 localStorage；二维码/URL/日志不出现 token。

## 6. 验证

- 单测：登记接口 204、非法 ID 400、名称解析、持久化、firstSeen 不丢。
- 面板：二维码 URL 自动配对（内容断言），地址栏清理。
- 副屏：真实页面打开后 `screen_clients.json` 出现 `Mac · Chrome`。
- 安装后覆盖；主屏设备列表与副屏列表互不混。
