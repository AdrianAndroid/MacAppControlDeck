# 桌面宠物（Bongo 风格）实施计划

> 日期：2026-11-21  
> 状态：**待评审，未实施**  
> 目标：在 MacAppControlDeck 内新增一个透明桌面宠物模块：1 号 Bongo 结构，三档尺寸，四款首批皮肤 + 默认白猫，跟随键盘/鼠标动作，支持换肤、拖拽、暂停、位置记忆。  
> OpenSpec 变更：`add-desktop-pet`

## 1. 结论

第一版不是“只做一只会动的猫”，而是一个可长期挂着、可换、可关、可降级的小模块：

- 透明非激活面板，不抢焦点，不占 Dock。
- 小 / 中 / 大三档，窗口和点击拦截区一起缩放。
- 默认白猫 + 黑猫、橘猫、三花、小狗四款皮肤。
- 键盘分区高亮、左右爪响应、鼠标跟随、待机/睡觉。
- 关闭即释放 runtime，不做后台键盘监听。
- 没输入监控权限也能显示、眨眼、跟随鼠标，只是不响应键盘。
- 菜单栏、设置页、`pet.open` 内置操作三处入口齐全。

## 2. 第一版范围

### 做

1. `pet` 模块 + `PetRuntime` 懒加载。
2. 透明置顶 `NSPanel`，非激活、跨普通桌面、不覆盖全屏。
3. 三档尺寸：小 0.75 / 中 1.0 / 大 1.35。
4. 五套皮肤：经典白猫（默认）、黑猫、橘猫、三花、小狗。
5. 键盘主题：奶油白、深色、马卡龙（只换色，不重画结构）。
6. 键鼠输入监听 + 状态机：左右爪、双眼、耳朵、尾巴、惊讶、睡觉。
7. 拖拽、右键菜单、锁定位置、点击穿透。
8. 首启提示、权限降级、安全输入暂停、锁屏暂停。
9. 位置 / 皮肤 / 尺寸 / 开关状态持久化。
10. 单测、构建、实机多屏/权限/全屏验证、README 与归档。

### 不做

- 3D、Live2D、SceneKit、Electron/Tauri。
- 键盘内容记录、联网、云同步、账号。
- 多只宠物同屏。
- 皮肤包导入/导出、配件系统、节日自动换肤、手机面板控制、声音、手柄。
- 直接使用带水印/付费授权的第三方皮肤。

## 3. 已定默认值

| 项目 | 默认 |
|---|--- | --- |
| 模块 ID / 名称 | `pet` / “桌面宠物” |
| 默认皮肤 | 经典白猫 |
| 默认尺寸 | 中 |
| 默认位置 | 主屏右下角，Dock 上方 24pt |
| 启动行为 | 记住上次开关；首次安装显示一次 |
| 全屏 | 默认不覆盖；设置可开 |
| 多桌面 | 默认所有普通桌面 |
| 键盘高亮 | 左/右/中/功能四区，不做逐键 |
| 声音 | 默认关，首版不做 |
| 点击穿透 | 默认关，菜单栏可恢复 |
| 全局快捷键 | `⌃⌥P` 打开/关闭桌宠 |
| 常驻 | 关闭即释放；暂停互动保留窗口但停输入 |

## 4. 架构

```text
PetModule（轻量代理，长期存在）
└── runtime: PetRuntime?（打开桌宠才创建）
      ├── PetSettings（UserDefaults，pet. 前缀）
      ├── PetPanelController
      │     ├── PetPanel（NSPanel 子类）
      │     └── PetSceneView（SwiftUI 矢量渲染）
      ├── PetSkinCatalog（5 套皮肤 + 键盘主题）
      ├── PetInputMonitor（CGEventTap）
      ├── PetStateMachine（动作/表情状态）
      └── PetInteractionController（拖拽/右键/锁定/穿透）
```

注册点：

- `App/DeckApp.swift` 增加 `ModuleRegistry.shared.register(PetModule.shared)`。
- `SettingsView.swift` 增加 `SettingsTab.pet` 和侧栏分组。
- `BuiltinActions.swift` 增加 `pet.open`。
- `GlobalHotKeys.swift` 增加 `⌃⌥P`。
- `MenuBarController` 不需要改结构，模块菜单自动拼接。

## 5. 数据模型

### 5.1 PetSkin

```swift
struct PetSkin: Identifiable {
    enum BodyKind { case cat, dog }
    enum Pattern { case solid, tabby, calico }

    let id: String
    let name: String
    let bodyKind: BodyKind
    let pattern: Pattern
    let palette: PetPalette
    let artBounds: CGRect          // 归一化 0...1，所有皮肤统一视觉槽位
    let hitOutline: [CGPoint]      // 归一化，身体 + 键盘，不含阴影/胡须
    let anchors: PetAnchors         // 左右手、眼睛、尾巴、耳朵
    let keyboardTheme: KeyboardTheme
    let license: String
}
```

### 5.2 尺寸

基准视觉槽位 `240 × 140`，窗口加 4pt 抗锯齿留边：

| 档位 | scale | 视觉尺寸 | 窗口约 | 细节 |
|---|---:|---:|---:|---|
| 小 | 0.75 | 180 × 105 | 188 × 113 | 隐藏键帽文字，胡须 2 根，简化阴影 |
| 中 | 1.0 | 240 × 140 | 248 × 148 | 标准键帽和五官 |
| 大 | 1.35 | 324 × 189 | 332 × 197 | 完整细节 + 轻投影 |

规则：

- 窗口大小 = `skin.artBounds × scale + padding`。
- 切换尺寸以底部中心为锚点，180ms 动画。
- 切换皮肤时，所有皮肤缩放到同一视觉槽位，避免换狗后窗口突然变宽。
- 多屏/分辨率变化后夹回 `NSScreen.visibleFrame`。

### 5.3 皮肤配色

| 皮肤 | 身体 | 描边 | 耳内/肉垫 | 眼睛 | 键盘 |
|---|---|---|---|---|---|
| 经典白猫 | `#F6F1E6` | `#2B2622` | `#F3B7B7` | `#2B2622` | 奶油白 |
| 黑猫 | `#252525` | 奶油白外描边 `#F2E4CB` + 深色内线 | `#E9A7B4` | `#86CC72` | 奶油白 |
| 橘猫 | `#E79A4C` | `#3A2A22` | `#F2B6A0` | `#C47A2B` | 奶油白 |
| 三花 | `#FFF9EE` | `#2B2622` | `#F2B6C0` | `#C8872C` | 奶油白 |
| 小狗 | `#F0D6A2` | `#4A3528` | `#F3C4C4` | `#3A2A22` | 奶油白 |

键盘主题：

- 奶油白：底 `#FFFDF7`，键帽 `#F3EBDD`，描边 `#D8CBB8`
- 深色：底 `#34302C`，键帽 `#4A443E`，描边 `#211E1B`
- 马卡龙：底 `#FFF7F4`，键帽 `#FFD7DE` / `#CFE9E3` / `#FFE7B8`

## 6. 分步执行

### Phase 0：OpenSpec 与规格冻结

**做什么：**

1. 新建 `openspec/changes/add-desktop-pet/proposal.md`：Why、What Changes、Capabilities、Impact、非目标。
2. 新建 `design.md`：架构、面板、尺寸、拦截、皮肤、输入、权限、性能。
3. 新建 `specs/desktop-pet/spec.md`：用 Given/When/Then 写清行为。
4. 新建 `tasks.md`：按本计划拆成可勾选任务。
5. 不改任何源码，先等你确认规格。

**验收：**

- 四个文件齐全，能反向对应本计划。
- 规格覆盖关闭释放、权限降级、三档尺寸、四皮肤、点击穿透、隐私。
- 没有“实现后再补规格”的情况。

### Phase 1：模块骨架与入口

**文件：**

```text
Sources/MacAppControlDeck/Modules/Pet/
  PetModule.swift
  PetRuntime.swift
  PetSettings.swift
```

**做什么：**

1. `PetModule` 实现 `FeatureModule`：`id=pet`、标题、图标、默认启用、`start/stop`。
2. `PetRuntime` 先只持有 `PetPanelController`，不接输入。
3. `DeckApp` 注册模块。
4. `BuiltinActions` 增加 `pet.open`，`run` 接 `PetModule.shared.toggle()`。
5. `GlobalHotKeys` 增加 `⌃⌥P`，绑定 `PetModule.shared.toggle()`。
6. `PetSettings` 只存 `pet.visible`、`pet.skin`、`pet.size`、`pet.frameByScreen`。
7. 菜单先只放“打开桌宠 / 关闭桌宠 / 桌宠设置…”。

**验收：**

- 菜单、快捷键、内置操作都能打开一个空白透明面板。
- 关闭后 `PetRuntime=nil`，没有后台定时器。
- App 仍不显示 Dock 图标。

### Phase 2：面板、尺寸、位置、拦截

**文件：**

```text
PetPanel.swift
PetPanelController.swift
PetGeometry.swift
PetPositionStore.swift
```

**做什么：**

1. `PetPanel`：`NSPanel` 子类，`styleMask=[.borderless, .nonactivatingPanel]`，`level=.floating`，`isOpaque=false`，`backgroundColor=.clear`，`hasShadow=false`，`canBecomeKey=false`。
2. `collectionBehavior=[.canJoinAllSpaces]`，先不加 `.fullScreenAuxiliary`；设置“允许覆盖全屏”时才加。
3. `PetGeometry`：三档尺寸、窗口 frame、底部中心锚点、可见区域 clamp。
4. `PetPositionStore`：按 `NSScreen` UUID + 归一化坐标保存；显示器变化时回退主屏。
5. `PetHitRegion`：从 `skin.hitOutline` 生成 `CGPath`，包含身体 + 键盘，不含阴影/胡须/透明留白。
6. `PetPanelController`：
   - 窗口只包住视觉槽位；
   - 鼠标在 hit path 内 `ignoresMouseEvents=false`；
   - 鼠标离开 4pt 滞回后 `ignoresMouseEvents=true`；
   - 无输入监控权限时，用 30Hz `NSEvent.mouseLocation` 轮询；再失败则退回“紧贴窗口”的矩形拦截，不退全屏。
7. 切换尺寸/皮肤时，先算新 frame，再更新 hit path，最后动画。

**验收：**

- 三档窗口尺寸正确，小档明显小于大档。
- 点猫外 4pt 能点到下层窗口。
- 拖到屏幕边缘自动夹回；重启恢复位置。
- 多屏拔插后不会出现在屏幕外。

### Phase 3：皮肤与矢量渲染

**文件：**

```text
PetSkin.swift
PetSkinCatalog.swift
PetPalette.swift
PetVectorArt.swift
PetKeyboardView.swift
PetSceneView.swift
PetRenderer.swift
```

**做什么：**

1. 定义 `PetSkin`、`PetPalette`、`PetAnchors`、`KeyboardTheme`。
2. 建立 5 套皮肤：白猫、黑猫、橘猫、三花、小狗；猫共用身体骨架，狗只换耳/尾/口鼻。
3. 用 SwiftUI `Path/Shape` 画：身体、头、耳、眼、瞳孔、口鼻、左右手、肉垫、尾巴、键盘、键帽。
4. 1 号风格约束：粗描边、纯色平涂、无渐变、小键盘、贴纸感；不在小尺寸堆细节。
5. 键盘只做四个区域高亮，不做逐键；小档隐藏键帽字母。
6. 皮肤切换 150ms 淡入 + 轻微弹一下；切换后更新窗口和 hit path。
7. `PetRenderer` 留协议，未来可替换为 sprite/Live2D，不改外层。

**验收：**

- 5 套皮肤在中档都能一眼区分。
- 小档不糊，大档不空。
- 黑猫在深色壁纸下仍有奶油色外描边。
- 换肤不改变位置，尺寸档位不跳。

### Phase 4：输入与状态机

**文件：**

```text
PetInputMonitor.swift
PetStateMachine.swift
PetAnimationClock.swift
PetKeyZone.swift
```

**做什么：**

1. `PetInputMonitor` 用 `CGEventTap`，`.cgSessionEventTap`、`.listenOnly`、`.headInsertEventTap`，监听：
   - keyDown / keyUp / flagsChanged
   - mouseMoved / leftMouseDown / rightMouseDown / scrollWheel
2. 只读 `keyCode`、左右位置、是否 autorepeat；不读字符、不写日志。
3. `IsSecureEventInputEnabled()` 为 true 时暂停键盘；锁屏/休眠停 tap，解锁/唤醒恢复。
4. tap 被系统 `tapDisabledByTimeout` 时自动重建。
5. `PetKeyZone`：ANSI 60% 布局表 `keyCode -> left/right/center/function`；未知键归 none，不做随机。
6. 状态机：
   - idle：呼吸、眨眼、耳朵抖、尾巴摆
   - 左/右爪按下、双手、惊讶
   - 120ms 内 3 个不同键 -> “被按懵”，800ms 锁
   - 3–5 分钟无输入 -> 睡觉；任意键盘/鼠标唤醒
7. 动画时钟：空闲 12fps，动作 30fps；窗口遮挡/隐藏/低电量降到 8–12fps。
8. 鼠标跟随：全局坐标 -> 面板坐标 -> 瞳孔/头部偏移，30Hz 节流；靠近爪子 40pt 时抬爪。

**验收：**

- 按键到爪子落下 < 80ms。
- 长按只触发一次，不抖动。
- 密码框/锁屏时不动，恢复后正常。
- 没有权限时只失去键盘反应，鼠标跟随仍可用。
- 空闲 CPU < 2%，持续打字 < 8%。

### Phase 5：交互、菜单、设置、首启

**文件：**

```text
PetInteractionController.swift
PetSettingsView.swift
PetMenuBuilder.swift
```

**做什么：**

1. 拖拽：按住身体拖动面板，拖起时四肢下垂，松手回弹；锁定位置后不响应拖动。
2. 右键菜单：换肤、尺寸、暂停互动、锁定位置、点击穿透、设置、关闭。
3. 双击：摸头/脸红，不抢焦点。
4. 点击穿透：`ignoresMouseEvents=true`，菜单栏和 `⌃⌥P` 必须能恢复。
5. 设置页：
   - 预览 + 5 皮肤网格
   - 尺寸分段控件
   - 键盘主题
   - 开机随机皮肤（默认关）
   - 睡眠时间（关/5/10/20 分钟）
   - 跟随鼠标 / 悬停摸头
   - 锁定位置 / 点击穿透
   - 允许覆盖全屏
   - 权限状态 + 去授权
   - 隐私说明：不记录按键、不联网
   - 重置位置
6. 首启提示：一次性气泡“拖动我，右键换肤”，5 秒消失；权限缺失时显示小徽标，不反复弹系统框。
7. R0 检查：`pet.open` 可从“设置 → 按钮管理 → 添加内置操作”添加；菜单栏和手机面板快捷操作都能出现。

**验收：**

- 菜单项状态（当前皮肤/尺寸/暂停/锁定）有勾选。
- 设置改动即时生效并持久化。
- 关闭再打开恢复皮肤/尺寸/位置。
- 点击穿透开启后能从菜单栏关闭。

### Phase 6：系统集成与边界

**做什么：**

1. 全屏：默认不覆盖其他 App 全屏；设置“允许覆盖全屏”才加 `.fullScreenAuxiliary`。
2. 多桌面：普通桌面都显示；全屏空间不显示。
3. 自带截图/录屏：如果 `CaptureModule` 能提供开始/结束通知，则录制期间隐藏；没有通知就先加一个轻量 `CaptureActivity` 通知，不影响 capture 行为。
4. 屏幕锁定/休眠：停 tap、停动画；解锁/唤醒恢复，但不要覆盖用户手动“暂停互动”。
5. 低电量/减弱动态效果：降帧、去掉弹跳，只留淡入淡出。
6. 显示器变化：监听 `NSApplication.didChangeScreenParametersNotification`，重算位置。

**验收：**

- 其他 App 全屏时默认看不到桌宠；开启开关后才覆盖。
- 自己录屏时桌宠不出现在成片（如果 capture 通知接入）。
- 锁屏再解锁不会出现 tap 残留或双份动画。

### Phase 7：测试与验收

**自动测试：**

```text
Tests/MacAppControlDeckTests/
  PetGeometryTests.swift       三档尺寸、锚点、clamp、hit path
  PetSkinCatalogTests.swift    5 套皮肤、配色、hit outline 完整
  PetStateMachineTests.swift   左右爪、组合键、睡觉/唤醒、去重
  PetSettingsTests.swift       持久化、默认值、无效值回退
  PetRuntimeTests.swift        打开/关闭释放、暂停不释放、重复开关不累积
```

**命令：**

```bash
swift test
./Build/build.sh
```

**实机矩阵：**

- 权限：有/无输入监控；拒绝后静态模式；授权后恢复。
- 输入：打字、长按、组合键、鼠标移动、点击、滚动、拖拽。
- 尺寸：S/M/L 切换，点猫外 4pt 穿透。
- 皮肤：5 套逐套切换；黑猫深色壁纸；小狗宽耳。
- 屏幕：双屏、拔掉副屏、分辨率变化、全屏 App、切换桌面。
- 状态：锁屏/解锁、休眠/唤醒、Secure Input、暂停互动。
- 性能：空闲 5 分钟 CPU、连续打字 1 分钟 CPU/内存。
- 恢复：重启 App 后位置/皮肤/尺寸/开关。
- 入口：菜单、`⌃⌥P`、内置操作、设置页按钮。

**通过线：**

- 按键延迟 < 80ms。
- 空闲 CPU < 2%，持续打字 < 8%，内存 < 60MB。
- 拦截轮廓与可见轮廓误差 ≤ 4pt。
- 无键盘文本日志、无网络请求。
- `swift test` 全通过，release 构建签名成功。

### Phase 8：文档、归档、提交

**做什么：**

1. README 增加“桌面宠物”章节：入口、三档、五皮肤、权限、隐私、点击穿透恢复。
2. 截图：菜单、设置页、五皮肤拼图、S/M/L 对比、点击穿透状态。
3. `Docs/architecture/MODULES.md` 增加 `pet` 模块。
4. `Docs/archive/2026-11-21-desktop-pet/SUMMARY.md` 记录实现、验证、已知限制。
5. OpenSpec 归档到 `openspec/changes/archive/2026-11-21-add-desktop-pet/`。
6. 同步 `openspec/specs/desktop-pet/spec.md`。
7. 提交：`feat(pet): add desktop pet with skins and responsive hit area`。

## 7. 风险与回退

| 风险 | 回退 |
|---|---|
| 没有输入监控权限 | 静态模式：显示、眨眼、鼠标跟随；设置页引导授权 |
| `ignoresMouseEvents` 边缘闪烁 | 4pt 滞回 + 30Hz 节流；仍失败则紧贴窗口矩形拦截 |
| CGEventTap 被系统禁用 | 监听 `tapDisabledByTimeout`，自动重建 |
| 全屏覆盖不适配 | 默认不加 `.fullScreenAuxiliary`；设置开关控制 |
| 多屏坐标错位 | 统一用屏幕 UUID + 归一化坐标；每次显示前 clamp |
| 逐键高亮在非 ANSI 键盘错位 | 只做四区高亮，不做逐键承诺 |
| 矢量猫不够可爱 | 保持 `PetRenderer` 协议，后续换 sprite/Live2D，不改外层 |
| 动画吃 CPU | 12/30fps 动态时钟；遮挡/隐藏/低电量降帧 |
| 换肤后拦截区没更新 | 皮肤切换统一走 `applySkin`，先 frame、再 hit path、再动画 |

## 8. 时间估算

按半天粒度，不含等待评审：

| 阶段 | 预估 |
|---|---:|
| Phase 0 OpenSpec | 0.5 天 |
| Phase 1 骨架入口 | 0.5 天 |
| Phase 2 面板/尺寸/拦截 | 1 天 |
| Phase 3 皮肤渲染 | 1.5 天 |
| Phase 4 输入/状态机 | 1.5 天 |
| Phase 5 交互/菜单/设置 | 1 天 |
| Phase 6 系统边界 | 0.5 天 |
| Phase 7 测试验收 | 1 天 |
| Phase 8 文档归档 | 0.5 天 |
| **合计** | **约 8 个工作日** |

## 9. 评审时要确认的点

1. 是否同意“关闭即释放、暂停保留窗口但停输入”。
2. 是否同意“默认不覆盖全屏，设置可开”。
3. 是否同意“键盘只做四区高亮，不承诺逐键”。
4. 是否同意首版不做配件、声音、皮肤包、手机控制。
5. 是否接受 `⌃⌥P` 作为桌宠开关快捷键。

确认后按 Phase 0 开始，先建 OpenSpec，不直接写代码。
