# 提案：修复区域截图菜单图标并拆分设置信息架构

## Why

用户反馈两个可见问题：

1. 菜单栏「快捷操作」置顶的「区域截图」没有图标；截图与录屏子菜单里的「区域截图」也缺少图标。原因是 `CaptureModule` 使用了不存在的 SF Symbol `selection`。
2. 设置「通用」页实际展示远程面板、权限、设备配对等电脑控制内容，缺少真正的通用项，信息架构不合理。

## What Changes

- 把「区域截图」菜单项图标改为有效的 SF Symbol `rectangle.dashed`，置顶克隆项与子菜单项共用该图标。
- 调整设置侧栏：
  - 「应用 → 通用」只保留应用级设置：登录时自动启动、数据与日志目录。
  - 「电脑控制 → 服务」承载远程面板、权限检查、设备配对与局域网安全提示。
  - 「按钮」「设备」保持在「电脑控制」分组。
- 「配对手机…」动作打开「电脑控制 → 服务」而不是「通用」。
- 设备页空状态文案从「通用」改为「服务」。

**非目标**：

- 不改变远程服务、权限检查、配对协议和按钮配置逻辑。
- 不重新设计设置窗口视觉，只调整分组与页面归属。
- 不新增新的远程控制能力。

## Capabilities

### New Capabilities

- `settings-navigation`：设置侧栏分组与页面职责。
- `menu-item-icons`：菜单项图标必须使用有效 SF Symbol。

## Impact

- 代码：`Modules/Capture/CaptureModule.swift`、`UI/SettingsView.swift`、`Modules/RemoteControl/RemoteControlModule.swift`。
- 文档：README 设置章节、`Docs/archive/2026-11-21-settings-ia-and-capture-icon/SUMMARY.md`。
- OpenSpec：新增 `settings-navigation` 与 `menu-item-icons` 能力规格。
