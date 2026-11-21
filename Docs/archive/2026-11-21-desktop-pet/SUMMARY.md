# 桌面宠物（Bongo Cat 结构）实施记录

- 日期：2026-11-21
- OpenSpec：`add-desktop-pet`
- 能力规格：`openspec/specs/desktop-pet/spec.md`
- 状态：已完成并覆盖安装

## 1. 需求

在 MacAppControlDeck 中增加一个类似 Bongo Cat 的桌面宠物：

- 透明、置顶、无边框、不抢焦点
- 跟随键盘与鼠标做出反应
- 三档尺寸（小 / 中 / 大），窗口、视觉和点击拦截区一起缩放
- 五套皮肤：经典白猫、午夜黑猫、橘子虎斑、三花猫、奶油小狗
- 透明区域点击穿透，只有身体和键盘拦截
- 无输入监控权限时降级，仍能显示、眨眼、跟随鼠标
- 隐藏时释放窗口、输入监听和动画资源

## 2. 实现

### 2.1 模块与生命周期

- 新增 `pet` FeatureModule，`PetModule` 只做轻量代理，首启自动显示一次。
- `PetRuntime` 组合 `PetSettings`、`PetStateMachine`、`PetAnimationClock`、`PetPanelController`、`PetInputMonitor`。
- 隐藏后异步释放 runtime；重新打开重建窗口与监听。
- 位置按显示器保存，默认主屏右下角 Dock 上方 24pt；多屏变化时 clamp 回可见区域。

### 2.2 窗口与点击

- `PetPanel`：无边框 `NSPanel`，`isOpaque=false`、`backgroundColor=.clear`、`level=.floating`、`collectionBehavior` 支持全屏辅助。
- `PetPanelController`：30Hz 悬停检测，4pt 滞回；命中路径只包含身体与键盘，透明区域切 `ignoresMouseEvents`。
- 三档尺寸：小 `188×113`、中 `248×148`、大 `332×197`（含 4pt 窗口留边）；切换以底部中心为锚点，180ms 动画。

### 2.3 皮肤与渲染

- `PetSkin` 定义五套皮肤的颜色、锚点与共享拦截区；黑猫用奶油描边，三花用黑/橘/白斑，小狗用垂耳与吐舌。
- `PetVectorArt` 用 SwiftUI `Canvas` 纯矢量绘制角色、迷你键盘、鼠标与爪子，不依赖位图资源。
- 键盘分区高亮：左/右/中/功能四区，按物理键码映射，不记录字符。
- 键盘主题：奶油白、深色、马卡龙。

### 2.4 输入与状态

- `PetInputMonitor`：`CGEventTap` listen-only，监听 keyDown / keyUp / flagsChanged / mouseMoved / scrollWheel；tap 被系统禁用后自动重建。
- `PetStateMachine`：左右爪起落、四区高亮、三键惊讶、眨眼、呼吸、尾巴、耳朵、鼠标眼珠、拖拽、悬停摸头、睡觉/唤醒。
- 帧率：空闲 12fps、动作 30fps；支持系统「减弱动态效果」。
- 系统边界：Secure Input、锁屏、休眠、低电量、全屏应用、自带录屏时自动暂停或隐藏，恢复后不覆盖手动暂停。

### 2.5 入口

- 菜单栏「桌面宠物」：打开/隐藏、暂停、点击穿透、尺寸、换肤、重置位置、设置页。
- 全局快捷键 `⌃⌥P`。
- 内置操作 `pet.open`，名称「打开桌面宠物」，符号 🐾。
- 设置页新增「桌面宠物」：状态卡、实时预览、五皮肤、三尺寸、键盘主题、行为、系统边界、权限与隐私。

## 3. 验证

- `swift test`：84 项通过，0 失败。
- 新增测试：`PetGeometryTests`、`PetSkinCatalogTests`、`PetStateMachineTests`、`PetSettingsTests`、`PetRenderSnapshotTests`、`PetPanelControllerTests`、`PetRuntimeTests`。
- 5 套皮肤 × 3 档尺寸共 15 张渲染快照全部成功，小狗垂耳已修正。
- 实机验证：白猫/三花/大号切换、键盘按住 Q 时粉色四区高亮、设置页预览、菜单勾选、右键菜单、隐藏释放均通过。
- `./Build/build.sh` 成功，签名 `MacAppControlDeck Self-Signed`；覆盖安装 `/Applications/MacAppControlDeck.app` 后进程正常运行。

## 4. 踩坑

1. **键盘行字符串越界导致 SIGILL**：`PetVectorArt.drawKeyboard` 以固定 10 列遍历，但部分行的标签不足 10 个；崩溃报告为 `Swift runtime failure: Index out of range`。改为以 `labels.count` 为列上限。
2. **调试器触发系统授权框**：首次用 lldb 启动时出现 `Developer Tools Access` 授权框，阻塞启动；关闭调试器后正常。
3. **大尺寸 clamp 影响测试期望**：窗口靠近屏幕边缘时 resize 会 clamp midX；测试按 clamp 后的期望修正，而不是假设绝对中心。
4. **透明窗口点击路径**：不能直接用整个窗口矩形拦截，否则透明留白会挡住下层应用；改为归一化轮廓路径，并随尺寸缩放。
5. **狗耳层级**：垂耳最初画在头前，像两块圆饼；改为头后绘制、缩小并外移后更像耳朵。

## 5. 产物

- 代码：`Sources/MacAppControlDeck/Modules/Pet/`
- 测试：`Tests/MacAppControlDeckTests/Pet*Tests.swift`
- 计划：`Docs/plans/2026-11-21-desktop-pet.md`
- README 截图：`Docs/images/readme/desktop-pet-hero.png`、`desktop-pet-skins.png`、`desktop-pet-settings.png`
- OpenSpec 归档：`openspec/changes/archive/2026-11-21-add-desktop-pet/`
