# 提案：设置页深链接与安装后直接打开桌宠设置

## Why

安装脚本目前只弹窗告诉接收方「去菜单栏找图标、点桌面宠物」，对电脑小白仍然绕。更直接的做法是装完自动把「设置 - 桌面宠物」打开，让他立刻看到可调的桌宠选项。

但 App 是菜单栏应用，外部无法直接命令它打开某个设置页，需要新增一个稳定的深链接入口 `macappcontroldeck://settings/pet`。

## What Changes

- 新增 URL scheme `macappcontroldeck`（`CFBundleURLTypes` 注册），支持：
  - `macappcontroldeck://settings/pet`（推荐）
  - `macappcontroldeck://settings?tab=pet`
  - 其余设置页同样可用：general / menu / modules / capture / sketch / calendar / pet / buttons / devices / service / about
- `AppDelegate` 处理 `application(_:open:)`：应用未完成启动时先缓存目标标签，启动完成后立即打开设置窗口并切到对应页。
- 安装脚本安装成功后自动执行 `open macappcontroldeck://settings/pet`（最多重试 6 次）；打不开时弹窗给出「菜单栏 → 设置 → 桌面宠物」的手动路径。
- 安装脚本增加 EXIT trap：任何未预期失败都会弹窗提示并指向 `/tmp/deck-install.log`，不再只有部分分支弹窗。

**非目标**：

- 不做通用命令总线，只暴露设置页跳转。
- 不改变 App 已有的菜单、快捷键与内置操作入口（沿用电脑控制/桌宠模块入口，不需要新增按钮）。
- 不引入账号、网络或自动化权限。

## Capabilities

### New Capabilities

- `settings-deeplink`：`macappcontroldeck://` 深链接的 scheme、路径/参数与目标设置页映射。

### Modified Capabilities

- `release-installer`：安装成功后自动打开桌宠设置；任何未预期失败都必须弹窗。

## Impact

- 代码：`Sources/MacAppControlDeck/App/DeckApp.swift`、`Build/Info.plist`、`Build/install-friendly.command`、`Build/install-readme.txt`。
- 规范：归档时新增 `openspec/specs/settings-deeplink/spec.md`，同步 `openspec/specs/release-installer/spec.md`。
- 发布物：DMG 内脚本行为变化；App 增加一个 URL scheme 注册。
- 权限/数据：不新增 TCC 权限；不写入新配置项。
