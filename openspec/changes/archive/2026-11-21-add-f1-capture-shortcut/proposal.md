# 提案：F1 区域截图全局快捷键

## Why

用户长期使用 Snipaste 的 `F1` 启动区域截图，已经形成肌肉记忆。Snipaste 已从本机删除，用户在 MacAppControlDeck 中需要同样顺手的入口，而不是每次都点菜单栏「截图与录屏 → 区域截图」。

现有截图模块已注册 Carbon 全局热键（`⌘⇧X` 区域、`⌘⇧F` 全屏等），具备不依赖辅助功能、在其他应用前台时也能响应的基础。新增 `F1` 只是增加一个绑定，不需要新权限、新服务或新模块。

## What Changes

- 在全局热键中新增 `F1`（无修饰键，keyCode 122），行为与 `⌘⇧X` 相同：打开区域截图覆盖层。
- 保留现有 `⌘⇧X`，两个快捷键都可触发区域截图；连按时由覆盖层协调器丢弃上一轮，不叠加遮罩。
- F1 通过 `CaptureModule.shared.captureArea()` 触发，确保截图前同步保存目录、延时时长、格式等偏好。
- 在「截图与录屏设置」的截图卡片中显示 `F1` 提示，README 与 macshot 移植文档补充快捷键说明。
- 不新增可编辑快捷键 UI；F1 为固定内置快捷键。

**非目标**：

- 不接管 macOS 的亮度/媒体键模式；Apple 键盘默认把 F1 用作亮度调节时，需要系统设置切换为「标准功能键」。
- 不把 F2–F12 绑定到截图或录屏动作。
- 不改变手机面板的快捷操作语义，也不新增用户可见模块或内置打开按钮。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `capture-overlay-parity`：新增「F1 区域截图热键」要求，明确与 `⌘⇧X` 并存、注册失败重试与键盘功能键模式限制。

## Impact

- 代码：`Sources/MacAppControlDeck/App/GlobalHotKeys.swift`、`Sources/MacAppControlDeck/Modules/Capture/CaptureSettingsView.swift`。
- 文档：`README.md`、`Docs/architecture/MACSHOT_PORT.md`、本变更归档。
- 测试：补充全局热键配置测试；全量 `swift test` 回归。
- 权限/API/数据：无新增。仍使用现有屏幕录制权限与 Carbon 注册。
- 用户可见入口：截图模块已有菜单与内置操作入口；F1 是既有能力的快捷方式，不新增独立模块或打开按钮。
- 已知冲突：应用运行期间 F1 被系统级注册，会优先于前台应用；手机端「F1」快捷按钮也会被本程序截获，不再透传到目标应用。
