# 任务：切换 Wi-Fi 后自动更新面板地址并提供稳定地址

## 1. 地址模型

- [x] 1.1 `LANAddress.stableHost / stablePanelURL / stableScreenURL`
- [x] 1.2 `DeckState` 增加稳定地址发布属性与 `refreshAddresses()`
- [x] 1.3 `NWPathMonitor` 网络变化自动刷新
- [x] 1.4 菜单打开 / 设置页 onAppear / 启停服务时同步重算

## 2. UI

- [x] 2.1 菜单「复制稳定面板地址」
- [x] 2.2 菜单「刷新网络地址（切换 Wi-Fi 后）」
- [x] 2.2.1 菜单「显示面板二维码…」直达设置服务页
- [x] 2.3 设置服务卡片：当前 IP / 稳定地址两行
- [x] 2.4 设置服务卡片：稳定地址 + 当前 IP 二维码
- [x] 2.5 内置操作 `network.open`「打开网络地址」📶
- [x] 2.6 README 限制说明更新

## 3. 验证

- [x] 3.1 `LANAddressTests` 3 项通过
- [x] 3.2 `ShortcutActionsTests` 内置操作注册通过
- [x] 3.3 `swift build` 通过
- [x] 3.4 安装后 `.local` 地址访问 `/panel/` 返回 200
- [x] 3.5 二维码本地生成（CoreImage），无网络上传
- [x] 3.6 覆盖安装后台启动，未抢焦点
