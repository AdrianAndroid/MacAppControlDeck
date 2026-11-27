# lan-api 变更（add-network-address-refresh）

## ADDED Requirements

### Requirement: 稳定服务地址与网络变化刷新

系统 SHALL 在网络路径变化后刷新当前面板地址，并提供不随 Wi-Fi IP 变化的 Bonjour 稳定地址。

#### Scenario: 切换 Wi-Fi 后自动刷新

- **WHEN** Mac 从一个 Wi-Fi 切换到另一个 Wi-Fi
- **THEN** `NWPathMonitor` 触发后自动重算 `panelURL / screenURL / stablePanelURL / stableScreenURL`
- **AND** 菜单栏「电脑控制」再次打开时显示新 IP，不需要重启 App

#### Scenario: 稳定地址

- **WHEN** 服务运行中
- **THEN** 提供 `http://<LocalHostName>.local:<port>/panel/` 与 `/screen/` 地址
- **AND** 该地址在 Wi-Fi 切换后保持不变，可由 iOS Safari 通过 mDNS 解析
- **AND** `HostPolicy` 允许 `.local` Host

#### Scenario: 手动刷新

- **WHEN** 用户点击菜单「刷新网络地址（切换 Wi-Fi 后）」
- **THEN** 立即重算地址，菜单下次打开显示最新值

#### Scenario: 扫码迁移

- **WHEN** 打开 设置 → 电脑控制 → 服务
- **THEN** 展示稳定地址与当前 IP 两个二维码，手机相机扫码即可打开对应面板
- **AND** 二维码本地生成，不上传 URL 或任何数据

#### Scenario: 内置入口

- **WHEN** 从按钮管理添加「打开网络地址」
- **THEN** 点击后刷新地址并打开设置 → 电脑控制 → 服务
- **AND** 同步出现在菜单栏快捷操作与手机面板快捷操作

#### Scenario: 旧 origin 迁移

- **WHEN** 用户从旧 IP 地址迁移到稳定 `.local` 地址
- **THEN** 因 origin 不同需要重新配对一次
- **AND** 之后 Wi-Fi 切换不再改变 origin，无需重复配对
