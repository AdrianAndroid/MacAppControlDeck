# 提案：全局快捷键可开关、改键与重置

## Why

截图、草图、桌宠的内置全局快捷键写死在代码里。F1 与键盘亮度键、其他截图/录屏工具冲突时，用户只能彻底不用或改系统设置；⌘⇧X、⌘⇧F 等组合也可能和别的软件撞车。需要让用户自己决定哪些全局快捷键生效。

## What Changes

- 设置新增「快捷键」页：一个总开关 + 每个入口一行。
- 每个入口可单独启用/关闭、录制新组合、恢复默认。
- 「全部恢复默认」一键还原所有组合并重新启用。
- 被其他应用占用时显示「被其他应用占用」，并继续每 2 秒重试；本程序内组合重复时显示「组合重复」。
- 录制新组合期间临时注销全部全局热键，避免旧热键吞掉要录的按键；关闭弹窗后自动恢复。
- 配置落盘到 `~/Library/Application Support/MacAppControlDeck/hotkeys.json`，重装/重建后保留。
- 菜单里的 UI 草图 / 桌面宠物快捷键标签跟随用户设置，关闭后不再显示。
- 新增内置操作「打开快捷键设置」，升级后自动加入快捷操作；深链接 `macappcontroldeck://settings/hotkeys`。
- 编辑按钮快捷键时同样暂停全局热键。

**非目标**：

- 不改动手机面板上的按钮注入类快捷操作。
- 不允许把单个字母/数字注册成全局热键（F1–F12 除外）。
- 不做跨应用冲突的提前探测，只在注册失败时如实显示。

## Capabilities

### New Capabilities

- `global-hotkeys`：系统级快捷键的启用、改键、重置与冲突反馈。

## Impact

- 代码：新增 `GlobalHotKey.swift`、`GlobalHotKeyStore.swift`、`HotKeySettingsView.swift`；重构 `GlobalHotKeys.swift`；接线 `SettingsView`、`DeckApp`、`BuiltinActions`、`ConfigStore`、`ShortcutSheet`、`SketchModule`、`PetModule`。
- 数据：新增 `hotkeys.json`，默认全部启用，与旧版本行为一致。
- 测试：新增 8 项单元测试（默认目录、修饰键映射、校验、合并、落盘、实例开关与菜单同步）。
