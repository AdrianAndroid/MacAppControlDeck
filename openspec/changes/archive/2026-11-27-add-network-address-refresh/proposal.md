> 修正：真机测试发现该手机无法解析 `.local` 稳定地址，最终只保留「网络变化自动刷新 + 当前 IP 二维码」；稳定地址相关 UI/属性已移除，下方保留原始设计记录。

# 提案：切换 Wi-Fi 后自动更新面板地址并提供稳定地址

## Why

换 Wi-Fi 后 Mac 的局域网 IP 会变化，而手机主屏幕 Web App 收藏的是旧 IP，导致看起来"桌面端用不了了"。
当前菜单/设置里的 `panelURL` 只在启动或重启服务时计算，切换网络后仍显示旧地址；手机也没有一个明显入口拿新地址。

## What Changes

- `LANAddress` 新增稳定 Bonjour 地址：`http://<LocalHostName>.local:<port>/panel/`（副屏同理）。
- `DeckState` 监听 `NWPathMonitor`，网络路径变化时自动重算当前 IP / 稳定地址；菜单打开与设置页出现时也强制刷新一次。
- 菜单栏「电脑控制」新增「复制稳定面板地址」「刷新网络地址（切换 Wi-Fi 后）」「显示面板二维码…」。
- 设置 → 电脑控制 → 服务卡片增加「当前 IP / 稳定地址」两行，以及两个二维码（稳定地址、当前 IP），可直接用手机相机扫码打开。
- 新增内置操作 `network.open`「打开网络地址」，可从按钮管理添加到菜单快捷操作/手机面板。
- README 限制说明更新：推荐收藏稳定 `.local` 地址。

**非目标**：

- 不修改配对 token 的存储方式；从旧 IP 迁到稳定地址仍需重新配对一次。
- 不引入固定 IP、路由器 DHCP 保留或公网穿透。
- 不改 HTTP 端口与鉴权。

## Capabilities

### Modified Capabilities

- `lan-api`：服务地址可在网络变化后刷新，并提供不随 IP 变化的 `.local` 地址。

## Impact

- 代码：`Server/LANAddress.swift`、`App/DeckState.swift`、`Modules/RemoteControl/RemoteControlModule.swift`、
  `UI/SettingsView.swift`、`Control/BuiltinActions.swift`、README。
- 权限/数据：无新增权限；不持久化地址。
- 入口：菜单栏「电脑控制」直接可见；内置操作 `network.open`。
