# 提案：桌面宠物

## Why

用户希望 MacAppControlDeck 提供一个类似 Bongo Cat 的桌面陪伴宠物：透明悬浮在桌面上，跟随键盘和鼠标做出反应，并且能换肤、调尺寸、关闭后释放资源。第一版要求稳定、轻量、隐私安全，不做 3D/Live2D。

## What Changes

- 新增 `pet` FeatureModule 与 `PetRuntime`：打开时创建透明 `NSPanel`、输入监听、状态机和渲染器；关闭时整体释放。
- 新增三档尺寸：小 0.75 / 中 1.0 / 大 1.35；窗口、视觉和点击拦截路径一起缩放。
- 新增五套矢量皮肤：经典白猫（默认）、黑猫、橘猫、三花、小狗；支持键盘主题切换。
- 新增键鼠输入监听：左右爪、区域高亮、组合键惊讶、鼠标跟随、待机/睡觉；只读 `keyCode`，不记录文本。
- 新增点击拦截：透明区域穿透；拦截路径只包含身体和键盘，不含阴影和留白。
- 新增菜单、设置页、`⌃⌥P` 和 `pet.open` 内置操作。
- 新增权限降级：无输入监控权限时仍可显示和跟随鼠标，只是不响应键盘。
- 新增位置/皮肤/尺寸/开关持久化，支持多屏恢复和可见区域夹回。

**非目标：**

- 不做 3D、Live2D、SceneKit、Electron/Tauri。
- 不做键盘内容记录、联网、云同步、账号。
- 不做多只宠物同屏。
- 首版不做配件、皮肤包导入、手机面板控制、声音、手柄。
- 不使用带水印/付费授权的第三方皮肤。

## Capabilities

### New Capabilities

- `desktop-pet`：桌面宠物的生命周期、三档尺寸、点击拦截、五套皮肤、键鼠反应、权限降级与隐私约束。

## Impact

- 代码：`App/DeckApp.swift`、`App/GlobalHotKeys.swift`、`Control/BuiltinActions.swift`、`UI/SettingsView.swift`、新增 `Modules/Pet/`。
- 测试：新增 `PetGeometryTests`、`PetSkinCatalogTests`、`PetStateMachineTests`、`PetSettingsTests`、`PetRuntimeTests`。
- 文档：README、`Docs/architecture/MODULES.md`、`Docs/archive/2026-11-21-desktop-pet/SUMMARY.md`。
- OpenSpec：新能力 `desktop-pet`。
