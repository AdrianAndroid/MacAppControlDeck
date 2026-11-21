# 技术设计：桌面宠物 v4 分层栅格骨架

## 1. 总体方案

```text
CGEventTap / NSEvent.mouseLocation
        │
        ▼
PetInputMonitor ──► PetStateMachine (30Hz / 2Hz)
        │                 │
        │                 ├─ gaze: 屏幕方向 → 瞳孔 / 头
        │                 ├─ pose: 左臂 / 右臂权重
        │                 └─ keycaps: 真实按键 → 4 槽生命周期
        ▼
PetRuntime ──► PetPanelController ──► PetSceneView
                                      │
                    ┌─────────────────┴─────────────────┐
                    │ PetRenderStyle == .rasterV4        │
                    │   PetV4Canvas(layers, manifest)    │
                    │ PetRenderStyle == .vectorV2        │
                    │   PetVectorArt(existing)           │
                    └───────────────────────────────────┘
```

原则：

1. **只替换黑猫皮肤的渲染路径**。`midnight-black` 走 v4；其余皮肤走矢量。渲染器是策略，不是模块边界。
2. **头、瞳孔、手臂继续由状态机驱动**，渲染层不做物理。状态机保持可单测、无 UI。
3. **连续运动靠图层变换**，离散姿态靠短交叉淡化。禁止整只猫换帧造成双影。
4. **桌面场景必须真透明**。米色墙只存在于设计板，不进入 App 资源。

## 2. 画布与坐标系

- 设计坐标：左上角原点，x 向右，y 向下。
- 画布：`720 × 960`。
  - `0...900` 为内容区：猫、桌板、键盘、鼠标。
  - `900...960` 为接触阴影区，避免桌板底边被窗口裁断。
- 目标视觉尺寸：中号 `288 × 384`（内容 288×360 + 阴影 24）；小号 `230×307`；大号 `374×499`。窗口四周再加 4pt padding。
- 所有图层统一输出 `@2x`：`1440 × 1920`；提供 `@1x` 作为低内存回退。
- 状态机里的 `PetPoint` 继续使用 260×360 的旧设计坐标，v4 渲染时通过 `PetV4Layout.mapFromLegacy()` 一次性换算，避免把旧测试全部推翻。新代码不得再混用两套坐标。

关键锚点（720×900 内容坐标）：

| 名称 | 坐标 | 用途 |
| --- | --- | --- |
| `headPivot` | `(360, 548)` | 头部旋转轴，位于颈根 |
| `headCenter` | `(360, 385)` | 头部命中与视线参考 |
| `eyeLeft` | `(245, 420)` | 左瞳孔中心 |
| `eyeRight` | `(390, 420)` | 右瞳孔中心 |
| `shoulderLeft` | `(252, 560)` | 左臂旋转轴 |
| `shoulderRight` | `(475, 560)` | 右臂旋转轴 |
| `keyboardRect` | `(60, 700, 650, 120)` | 键盘命中与落点 |
| `mouseRect` | `(600, 742, 92, 68)` | 鼠标命中与按鼠标 |
| `tableTop` | `y = 690` | 桌板前缘 |

这些值写入 `manifest.json`，Swift 只读 manifest，不在视图里散落硬编码。

## 3. 图层拆分与 z 序

从下到上：

| z | 图层 | 说明 |
| --- | --- | --- |
| 0 | `shadow` | 桌板与猫的接触阴影，透明底，允许超出 900 内容区 |
| 1 | `table` | 木桌板，无墙面、无桌面杂物 |
| 2 | `body` | 猫身体、后腿、脚掌、尾巴；不含头、前臂、爪 |
| 3 | `keyboard` | 白键盘主体与橙键；不含猫爪 |
| 4 | `mouse` | 白鼠标 |
| 5 | `head` | 头、耳朵、脸颊、颈部；不含瞳孔和眼睑 |
| 6 | `pupilL` / `pupilR` | 黑色瞳孔 + 高光；在 head 组内做局部平移 |
| 7 | `lidL` / `lidR` | 眼睑，眨眼/眯眼时纵向拉伸覆盖眼球 |
| 8 | `armL_rest` / `armL_down` | 左臂，肩点为轴；休息、落键两态 |
| 9 | `armR_rest` / `armR_down` / `armR_mouse` | 右臂三态 |
| 10 | `keycaps` | 运行时绘制，不预烘焙 |

绘制顺序细节：

- `keyboard` 在 `body` 之后，所以键盘前缘会挡住猫下腹，符合参考图。
- `armL/armR` 在 `keyboard` 与 `mouse` 之后，爪子始终压在键帽/鼠标上。
- `head` 在 `body` 之后，头部旋转时由身体胸口填住颈根，不出现透明缝。
- `pupil/lid` 只在 head 变换内部绘制，跟随头一起动。
- 键帽永远在最上层，但不允许落进猫脸区域；槽位固定在人头上方和右侧。

## 4. 透明化与补洞

这是本变更的**关键路径**，必须先于 Swift 渲染完成。

### 4.1 资产生产

1. 以 `Docs/design/desktop-pet-v4-desk-keyframe.png`（1373×1717）为母版，缩放到 1440×1800，底部补 120px 透明阴影区到 1440×1920。
2. 去掉米色墙：只保留桌板轮廓、猫、键盘、鼠标和软阴影。桌板边缘做 2px 羽化，不做硬矩形裁切。
3. 用蒙版拆层：
   - 头：从耳尖到颈根，沿毛发边缘 1–2px 羽化；颈根多留 18px 藏在身体后面。
   - 身体：去掉头、前臂；颈部和两肩腋下用相邻毛发做局部补洞，补洞区至少 12px 重叠。
   - 手臂：按休息/落键/按鼠标三张关键帧拆；肩点附近保留 10px 身体色，避免旋转时露底。
   - 瞳孔：从 `desk-keyframe` 与 `gaze-right` 提取黑色瞳孔和高光，边缘 1px 羽化；眼白/虹膜留在 head 层。
   - 眼睑：用头部黑色毛发采样生成，闭合状态覆盖整个眼球，边缘带 3px 软过渡。
4. 每层输出 straight alpha PNG，不预乘；透明区域 RGB 必须归一到同色，防止缩放时出现白边/黑边。
5. 2× 放大目检接缝：颈根、左右腋下、尾根、桌板底边。接缝可见宽度 >2px 即返工。

### 4.2 降级方案

如果补洞仍不干净：

- 保留头/瞳孔/眼睑分层，手臂退化为“休息/落键/鼠标”三张**整身姿态帧**，120ms 交叉淡化，并在切换时加 2px 下压掩盖双影。
- 再不行则只上线“视线 + 头部微动 + 键帽”，姿态仍用矢量 V2；在 README 明确当前版本边界，不把半成品说成完成。

## 5. `manifest.json`

```json
{
  "version": 1,
  "canvas": [720, 960],
  "contentHeight": 900,
  "layers": {
    "table":  {"file": "table@2x.png", "z": 1},
    "body":   {"file": "body@2x.png", "z": 2},
    "keyboard": {"file": "keyboard@2x.png", "z": 3},
    "mouse":  {"file": "mouse@2x.png", "z": 4},
    "head":   {"file": "head@2x.png", "z": 5},
    "pupilL": {"file": "pupilL@2x.png", "z": 6},
    "pupilR": {"file": "pupilR@2x.png", "z": 6},
    "lidL":   {"file": "lidL@2x.png", "z": 7},
    "lidR":   {"file": "lidR@2x.png", "z": 7},
    "armLRest": {"file": "armL-rest@2x.png", "z": 8},
    "armLDown": {"file": "armL-down@2x.png", "z": 8},
    "armRRest": {"file": "armR-rest@2x.png", "z": 8},
    "armRDown": {"file": "armR-down@2x.png", "z": 8},
    "armRMouse": {"file": "armR-mouse@2x.png", "z": 8}
  },
  "anchors": {
    "headPivot": [360, 548],
    "eyeLeft": [245, 420],
    "eyeRight": [390, 420],
    "shoulderLeft": [252, 560],
    "shoulderRight": [475, 560],
    "keyboardRect": [60, 700, 650, 120],
    "mouseRect": [600, 742, 92, 68]
  },
  "keycapSlots": [
    {"point": [290, 145], "rotation": -7},
    {"point": [445, 95],  "rotation": 4},
    {"point": [605, 165], "rotation": 7},
    {"point": [520, 190], "rotation": 3}
  ],
  "hitRegions": [
    {"rect": [150, 200, 370, 360], "shape": "ellipse"},
    {"rect": [175, 520, 370, 220], "shape": "ellipse"},
    {"rect": [60, 690, 650, 140], "shape": "roundedRect"},
    {"rect": [600, 735, 100, 80], "shape": "ellipse"}
  ]
}
```

- 加载时校验：所有文件存在、尺寸与 canvas 一致、alpha 非空、z 不重复。
- 任一校验失败：`PetV4AssetStore` 返回 `.unavailable(reason)`，渲染器回落矢量，不 crash。

## 6. 视线与头部微动

### 6.1 全屏光标方向

当前 `PetPanelController.normalizedMousePosition()` 是相对宠物窗口，光标稍微移动就饱和。v4 改为：

1. 由 `NSEvent.mouseLocation` 取屏幕坐标（左下原点）。
2. 取宠物所在 `NSScreen`，把猫头中心从窗口坐标转到屏幕坐标。
3. 计算 `dx = cursor.x - head.x`、`dy = cursor.y - head.y`。
4. 用视口尺度归一化：

```swift
let nx = clamp(dx / (screen.frame.width * 0.35), -1, 1)
let ny = clamp(dy / (screen.frame.height * 0.30), -1, 1)
```

5. 光标在另一块屏幕、或宠物在副屏时，仍以“宠物所在屏”的坐标边界计算，超过边界自然饱和到 ±1。

不使用 `CGEvent` 额外 tap；`NSEvent.mouseLocation` 不需要新权限。采样 30Hz，仅在面板可见时运行。

### 6.2 映射

| 输出 | 目标值 | 弹簧 | 上限 |
| --- | --- | --- | --- |
| 瞳孔 X | `nx * 10px` | stiffness 700 / damping 40 | ±10px |
| 瞳孔 Y | `-ny * 6px` | 同上 | ±6px |
| 头部偏航 | `nx * 3°` | stiffness 240 / damping 28 | ±3°，鼻尖位移 ≤8px |
| 头部俯仰 | `-ny * 2°` | 同上 | ±2°，垂直 ≤4px |
| 身体侧倾 | `nx * 1.0°` | stiffness 220 / damping 28 | ±1°，不能跟头一起大摆 |

实现细节：

- 头部旋转轴为 `headPivot`，旋转后叠加 `x = nx * 6px` 的头部位移补偿，保证耳尖不甩出画布。
- 俯仰不使用真 3D，而是 `translateY = -ny * 3px` + `scaleY = 1 - abs(ny) * 0.004`，读起来像轻微点头。
- 头部角度从 `headPivot` 反算：`nose = headCenter + (0,-120)`，对每帧角度检查 `abs(rotatedNose.x - nose.x) <= 8`，超限自动降压。
- 眼睛必须先到：瞳孔 spring 在 180ms 内到 95%；头 120ms 后才启动，240ms 缓出到 90%。用两个独立 spring，不共用目标时间。

### 6.3 优先级

1. 正在打字（`activeKeys` 非空或 `typingUntil` 未到）：视线看当前键，头向键盘偏 1.5°，忽略光标。
2. 右爪按鼠标（鼠标按下事件后 600ms）：视线看鼠标，头向鼠标偏 1.5°。
3. 其他：跟随全屏光标。
4. 睡眠/锁屏/Secure Input：目标冻结，眼睛回中，头回正。
5. `followMouse == false`：瞳孔和头都回中，仅保留呼吸/眨眼。

`reduceMotion == true`：取消头部偏航、尾巴和呼吸，只保留瞳孔 0.12s 跟随与眨眼；不做大幅位移。

## 7. 手臂姿态与落键

### 7.1 姿态权重

```swift
struct ArmWeights {
    var leftRest: CGFloat
    var leftDown: CGFloat
    var rightRest: CGFloat
    var rightDown: CGFloat
    var rightMouse: CGFloat
}
```

目标：

- 无按键：左 1/0，右 1/0/0。
- 左区或中区按键：左 0/1，右 1/0/0。
- 右区按键：左 1/0，右 0/1/0。
- 按鼠标：左 1/0，右 0/0/1。
- 左右同时按：两臂都 down。

权重用 120ms 线性/ease-out 过渡；`armL_rest` 与 `armL_down` 同时绘制，alpha 相加不为 1 时用 normal blend，避免双影过重。切换帧额外给 down 层 `y + 2px`，落键后再回弹。

### 7.2 落键冲击

每次非 repeat 的 keyDown：

- `armDownYOffset` 从 0 → +4px（80ms），再 +4 → 0（120ms，过冲 -1px）。
- 对应手臂层做 1.01 纵向压缩，模拟爪垫压键。
- 身体只给 1px 下沉，不做全身弹跳。
- 键帽在该 keyDown 同帧生成，不等待手臂到位。

### 7.3 按鼠标

- 右臂切 `armR_mouse`，权重 0→1 / 140ms。
- 鼠标图层自身下沉 2px，松开 120ms 回弹。
- 头向鼠标偏 1.5°，眼睛先锁鼠标。
- 按鼠标期间不生成键帽。

## 8. 键帽

### 8.1 生命周期

| 阶段 | 时间 | 行为 |
| --- | --- | --- |
| 生成 | 0ms | 在头顶后方 `slot.point + (0, 95)` 出现，scale 0.85，alpha 1 |
| 弹出 | 0–80ms | ease-out 到 `slot.point`，scale 0.85→1.2 |
| 悬浮 | 80–420ms | 正弦微摆 ±4px，保持 1.2 |
| 淡出 | 420–600ms | 上浮 18px，alpha 1→0，scale 1.2→1.25 |

- 最多 4 个；第 5 个到来时移除最旧的。
- 槽位固定 4 个，不横向挤开；淡出中的键帽仍占槽，防止新键帽叠到同一位置。
- 键帽字符取 `PetKeyMap.key(for:)?.label`，是键位常量，不是用户输入文本；不写日志、不持久化。
- 修饰键显示 `⌘ / ⇧ / ⌥ / ⌃ / fn`；长字符自动降字号。
- 键帽主体用 `keycap_blank@2x.png`；字符用 `GraphicsContext.draw(Text)` 叠加，跟着同一 transform 旋转/缩放/淡出，避免每个字符生成一张纹理。

### 8.2 防遮挡

- 四个槽位全部在猫头上方/右侧，`y <= 200` 或 `x >= 500`；不做“键帽落脸”。
- 字号按中号 13pt，随窗口尺寸等比缩放；小号最小 9pt，低于 9pt 只画键帽不画字符，保证可读性。

## 9. 时钟与性能

- 活动期：30fps（`1/30`），由 keyDown、鼠标移动、鼠标按下、hover 触发 0.9s 爆发。
- 跟随期：15fps，0.9s 后仍有光标移动时使用。
- 静止期：2fps，只跑呼吸/眨眼；没有可见变化时不重绘。
- `reduceMotion` 或低电量：15fps，禁用头部旋转/尾摆。
- 窗口隐藏、锁屏、录制隐藏：`PetAnimationClock.stop()` 或 2fps；不得后台 30fps 空转。
- 渲染：`Canvas` 一次合成 10 层，图层 `Image` 预解码并缓存；不做逐帧模糊/实时阴影。
- 内存目标：常驻 <80MB；1 小时无增长；资产按需加载，非黑猫不加载 v4。

## 10. 代码结构

```text
Modules/Pet/
├── PetV4/
│   ├── PetV4Layout.swift        // 坐标、缩放、命中换算
│   ├── PetV4AssetStore.swift    // manifest 解码、PNG 缓存、失败回退
│   ├── PetV4Rig.swift           // 头/瞳/臂的渲染变换值
│   ├── PetV4Canvas.swift        // SwiftUI Canvas 合成
│   ├── PetV4KeycapRenderer.swift// 键帽 4 槽与字符
│   └── PetV4Manifest.swift      // Codable 模型
├── Resources/PetV4/
│   ├── manifest.json
│   ├── shadow@2x.png
│   ├── table@2x.png
│   ├── body@2x.png
│   ├── head@2x.png
│   ├── pupilL@2x.png / pupilR@2x.png
│   ├── lidL@2x.png / lidR@2x.png
│   ├── armL-rest@2x.png / armL-down@2x.png
│   ├── armR-rest@2x.png / armR-down@2x.png / armR-mouse@2x.png
│   ├── keyboard@2x.png / mouse@2x.png
│   └── keycap-blank@2x.png
└── ...existing files
```

修改点：

- `PetTypes.swift`：增加 `PetRenderStyle`、`PetArmPose`、`headPitch`、`armWeights`、`keycap` 槽位字段；保持旧字段默认值，避免矢量视图崩。
- `PetStateMachine.swift`：接入全屏光标方向、头角度硬限、4 槽 0.6s、30fps 状态；保留旧 `handleMouseMoved` 作为兼容入口。
- `PetAnimationClock.swift`：20fps → 30fps；增加 15fps 中间档。
- `PetSceneView.swift`：按 `renderStyle` 选择 `PetV4Canvas` 或 `PetVectorArt`。
- `Package.swift`：`resources` 增加 `.copy("Modules/Pet/Resources")`。
- `PetGeometry.swift`：窗口/视觉尺寸切到 v4 基准；旧尺寸测试同步更新。
- `PetSettingsView.swift`：只补一句“黑猫为 v4 栅格；其他皮肤为矢量预览”，不新增开关。

## 11. 兼容与迁移

- `PetSettings.skinID` 不变；只有 `midnight-black` 走 v4。
- 已保存的窗口位置按归一化坐标恢复，尺寸变化后重新 clamp，不重置到右下角。
- `pet.renderV4` 默认 true；启动时做一次资产校验，失败则本次会话回退矢量并在设置页显示“v4 资产不可用”。
- 旧 `PetSnapshot` 的 `headYaw` 语义从“归一化 -1..1”改为“角度 -3..3”，矢量渲染需要乘以 2.33 保持原视觉幅度；所有测试同步。
- 未提交的 V2/V3 改动先单独提交或 stash，再开 v4 分支；不在同一工作树混改。

## 12. 测试与验收

### 12.1 单测

- `PetV4LayoutTests`：720×960 → 三档尺寸、锚点、命中区域、旧坐标换算。
- `PetV4AssetStoreTests`：manifest 解码、缺文件/尺寸不符/alpha 空时回退。
- `PetStateMachineV4Tests`：光标四角 → 眼 ±10/6、头 ±3/±2、鼻尖 ≤8px；打字优先、鼠标优先；`followMouse=false` 回中；`reduceMotion` 静止。
- `PetKeycapV4Tests`：0 键帽待机；第 5 个移除最旧；0.6s 后清空；标签正确；修饰键不写日志。
- `PetV4RenderSnapshotTests`：idle / gaze-left / gaze-right / typing / mouse / blink 六态，小中大三种尺寸。
- 既有 `swift test` 全绿。

### 12.2 目检

- 浅色/深色壁纸各一张：无米色墙、无矩形底、桌板阴影自然。
- 2× 放大看颈根、腋下、尾根：接缝 ≤2px，旋转 ±3° 不露底。
- 连续打字 30 秒：键帽不叠脸、不卡死、不超 4 个。
- 光标四角快速移动：眼先到、头后到；头不甩、身体不跟着扭。
- 按鼠标：右爪压鼠标、头偏 1.5°，松手回弹。
- 三档尺寸：耳尖、尾巴、桌板、鼠标不被裁。

### 12.3 性能

- M1 Mac mini：静止 CPU <3%、活动 <8%；内存 <80MB；1 小时无增长。
- 30fps 活动期掉帧 <5%；窗口隐藏后无 30fps 定时器。
- `swift test` 与 `./Build/build.sh` 通过，签名安装后实机 10 分钟无崩溃。

## 13. 风险

| 风险 | 影响 | 处理 |
| --- | --- | --- |
| 切图补洞露缝 | 高 | 先做 2× 目检；失败走整身姿态帧降级 |
| 头旋转露颈 | 高 | 颈根多留 18px、身体胸口填底、角度硬限 |
| 30fps Canvas CPU 高 | 中 | 图层缓存、仅活动期 30fps、空闲 2fps |
| 透明桌面场景不如设计板 | 中 | 桌板加软阴影与 2px 羽化；不放墙面 |
| 多屏坐标错 | 中 | 以宠物所在屏计算，四角/副屏单测 |
| 资产授权 | 中 | 只用自产/已确认素材；参考视频与 DesktopCat 素材不打包 |
| 与未提交 V2 改动冲突 | 中 | 先 stash/单独提交，再开分支 |
