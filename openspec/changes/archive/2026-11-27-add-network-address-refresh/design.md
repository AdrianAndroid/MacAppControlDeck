# 设计：切换 Wi-Fi 后自动更新面板地址并提供稳定地址

## 地址模型

- 当前 IP：`http://<首选局域网 IPv4>:<port>/panel/`，用于兼容所有设备。
- 稳定地址：`http://<ProcessInfo.hostName>:<port>/panel/`（如 `zhaojiandemacbook-pro.local`）。
  Wi-Fi 切换只改变 IP，`.local` 由 macOS Bonjour/mDNS 持续广播。
- 两个地址并存，不替换；旧手机收藏可用当前 IP 二维码立刻恢复，迁移到稳定地址后长期不再受 IP 影响。
- `HostPolicy` 已允许以 `.local` 结尾的 Host；服务本身监听所有接口，无需重启。

## 自动刷新

```swift
pathMonitor.pathUpdateHandler = { [weak self] path in
    guard path.status == .satisfied else { return }
    DispatchQueue.main.async { self?.refreshAddresses() }
}
```

- `DeckState.refreshAddresses()` 同时重算 `panelURL / screenURL / stablePanelURL / stableScreenURL`。
- `start()`、`stop()`、网络路径变化、菜单打开、设置页 `onAppear` 都调用同一函数。
- 菜单打开时同步重算一次，避免 `NWPathMonitor` 回调延迟导致仍显示旧 IP。

## UI

菜单栏「电脑控制」：

- `面板：<当前 IP>`（已有，现在会自动更新）
- 在浏览器打开面板 / 复制面板地址
- **复制稳定面板地址**（新增）
- **刷新网络地址（切换 Wi-Fi 后）**（新增）
- **显示面板二维码…**（新增，直接打开设置 → 电脑控制 → 服务）
- 副屏地址保持原有入口

设置 → 电脑控制 → 服务：

- 当前 IP 行：复制 / 打开
- 稳定地址行：复制 / 打开
- 右侧两个二维码：稳定地址、当前 IP；白色静区，手机相机扫码后直接打开。
- 文案说明切换 Wi-Fi 后 IP 会变，推荐收藏稳定地址。

二维码使用 CoreImage `CIFilter.qrCodeGenerator()` 本地生成，不上传任何数据；8 倍缩放 + 12pt 白边保证扫描。

## 迁移说明

- 稳定地址与旧 IP 是不同 origin，localStorage token 不共享；第一次改用稳定地址需要重新配对一次。
- 之后 Wi-Fi 任意切换，手机仍是同一 origin，无需再配对。
- IP 二维码作为兜底：如果某台手机无法解析 `.local`，仍可扫码用当前 IP 恢复。

## 内置入口（R0）

- 新增 `BuiltinActions`：`network.open`「打开网络地址」，符号 📶。
- 动作：刷新地址 → 打开设置 → 电脑控制 → 服务（二维码就在这里）。
- 可从「设置 → 按钮 → 添加内置操作」添加，并自动出现在菜单栏快捷操作与手机面板快捷操作。

## 验证

- `LANAddressTests`：稳定主机名 `.local`、端口与路径正确。
- `ShortcutActionsTests`：`network.open` 已注册。
- 安装后用稳定 `.local` 地址访问 `/panel/` 返回 200。
- 设置页二维码用本机生成图片验证有白边、可分辨。
