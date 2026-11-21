# 区域截图图标与设置信息架构修复（2026-11-21）

对应 OpenSpec 变更：[`fix-settings-ia-and-capture-icon`](../../../openspec/changes/archive/2026-11-21-fix-settings-ia-and-capture-icon/proposal.md)
能力规格：[`settings-navigation`](../../../openspec/specs/settings-navigation/spec.md) · [`menu-item-icons`](../../../openspec/specs/menu-item-icons/spec.md)

## 需求

用户反馈：

1. 菜单栏「快捷操作」置顶的「区域截图」没有图标。
2. 设置「通用」页大多是远程面板、权限、设备配对等电脑控制内容，不像通用设置。

## 实现

### 区域截图图标

- 根因：`CaptureModule` 使用 `NSImage(systemSymbolName: "selection")`，该符号在当前 macOS 上不存在，返回 `nil`。
- 改为有效符号 `rectangle.dashed`。
- 子菜单项与菜单栏置顶克隆项共用同一个 `image`，两处同时恢复图标。
- 已用 AppKit 验证 `rectangle.dashed`、`network`、`lock.shield`、`folder`、`power`、`iphone` 均存在。

### 设置信息架构

```text
应用
├── 通用       登录启动、数据与日志目录
└── 菜单       菜单置顶与显隐排序
模块
└── 模块       模块启用与常驻
电脑控制
├── 服务       远程面板、权限、设备配对
├── 按钮       按钮配置
└── 设备       已配对设备
截图与录屏
UI 草图
万年历
关于
```

- `SettingsTab` 新增 `.remoteService`。
- 「通用」只保留应用级设置：
  - 登录时自动启动；
  - 配置/设备目录、日志目录，可在 Finder 中显示。
- 原通用页的远程面板、权限卡、配对卡、HTTP 安全提示迁到「电脑控制 → 服务」。
- 菜单「配对手机…」改为打开「服务」页。
- 设备页空状态文案从「通用」改为「服务」。

## 验证

- `swift test`：58 个测试全部通过。
- `./Build/build.sh`：release 构建签名成功，覆盖安装到 `/Applications/MacAppControlDeck.app`。
- 实机菜单截图：`Docs/images/readme/menu.png`，置顶「区域截图」和子菜单项均显示虚线选区图标。
- 实机设置截图：
  - `Docs/images/readme/settings-general.png`：启动、数据与日志；
  - `Docs/images/readme/settings-service.png`：远程面板、权限、设备配对。

## 已知限制

- `rectangle.dashed` 的视觉含义是矩形选区，与具体截图工具品牌图标不绑定的设计一致。
- 「通用」页不包含主题、语言等尚不存在的应用级设置。
- 远程服务、权限检查和配对协议本身未改动。
