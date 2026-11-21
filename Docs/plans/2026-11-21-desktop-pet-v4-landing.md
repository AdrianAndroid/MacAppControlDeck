# 桌面宠物 v4 落地开发计划

> 日期：2026-11-21  
> 对应设计：`Docs/design/desktop-pet-v4-desk-keyframe.png`、`desktop-pet-v4-keycap-motion-board.png`、`desktop-pet-v4-gaze-motion-board.png`、`desktop-pet-v4-keycaps-preview.mp4`  
> 对应 OpenSpec：`openspec/changes/add-desktop-pet-v4-raster-rig/`  
> 状态：计划待评审，未开始改代码

## 1. 结论先行

这次不是“把矢量猫画得更像”，而是**换渲染路线**：

- 黑猫走 **分层栅格骨架**：身体、头、瞳孔、眼睑、左右手臂、键盘、鼠标、桌板分别出透明 PNG，在 SwiftUI `Canvas` 里按 z 序合成。
- 眼睛连续跟随整个屏幕的光标；头只做 **±3° 偏航 / ±2° 俯仰**，身体和桌子基本不动。
- 打字/按鼠标用 **手臂图层权重混合**，不整猫换帧。
- 键帽 **事件驱动**，最多 4 个、0.6s 寿命、顶面带本次真实按键字符。
- 其他四套皮肤继续走现有矢量实现，先保证不回归；狗皮肤后续单独立项。

一句话验收：**在真实桌面上看到的，应该就是那段已确认的 v4 预演，而不是一只会动的矢量贴纸。**

---

## 2. 当前基线（必须先知道）

| 项目 | 现状 | v4 目标 | 差距 |
| --- | --- | --- | --- |
| 渲染 | `PetVectorArt`，纯矢量 Canvas，624 行 | 分层透明 PNG + Canvas 合成 | 需要整套拆图与资源打包 |
| 视觉 | Bongo Cat 式矢量，细描边 | 2.5D 半写实黑猫、木桌、白键盘/鼠标 | 需要 v4 资产 |
| 眼睛 | 有 `eyeX/eyeY` spring | 全屏光标方向，±10/±6px | 当前以宠物窗口为参照，会饱和 |
| 头部 | `headYaw = gazeTargetX * 7` | ±3° 偏航 / ±2° 俯仰，鼻尖 ≤8px | 当前可能 ±7°，幅度过大 |
| 姿态 | 全身矢量整体变换 | 左右臂图层权重 + 落键冲击 | 需要拆臂与补洞 |
| 键帽 | 有字形；6 槽、0.44s、从爪边起 | 4 槽、0.6s、头顶后方、真实字符 | 参数与起点不一致 |
| 时钟 | 空闲 2fps、活动 20fps | 活动 30fps、跟随 15fps、空闲 2fps | 需要升帧与降级 |
| 窗口 | 260×360，三档 0.64/0.82/1.08 | 720×960 设计画布，三档透明场景 | 比例从 0.722 变 0.75 |
| 资源 | 仅打包 Sketch 资源 | 新增 PetV4 资源目录 | `Package.swift` 要改 |
| 桌面 | 透明窗口，但 v4 图有米色墙 | 桌板/猫/键鼠悬浮在真实桌面 | 必须去墙、去矩形底 |

**当前工作树有未提交改动**（`README.md`、`PetAnimationClock.swift`、`PetRig.swift`、`PetStateMachine.swift`、`PetTypes.swift`、`PetVectorArt.swift`）。动代码前先单独提交或 stash，不要在同一个工作树里混着改。

---

## 3. 目标架构

```text
┌─────────────────────────────┐
│ CGEventTap（只读 keyCode）   │
│ NSEvent.mouseLocation        │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ PetInputMonitor              │
│  - keyDown / mouseDown       │
│  - 全局光标 30Hz             │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ PetStateMachine              │
│  - gaze: nx/ny → 瞳/头       │
│  - pose: 左右臂权重          │
│  - keycaps: 4 槽 / 0.6s      │
│  - 优先级 / 降级             │
└──────────────┬──────────────┘
               ▼
┌─────────────────────────────┐
│ PetSceneView                 │
│  ├─ .rasterV4 → PetV4Canvas  │
│  └─ .vectorV2 → PetVectorArt │
└─────────────────────────────┘
```

设计原则：

1. 状态机保持纯逻辑，不碰 `NSImage`。
2. 渲染器只读快照与 manifest，不自己算物理。
3. v4 是黑猫皮肤的渲染策略，不是新模块。
4. 任何一步失败都能回退矢量，不阻断桌宠启动。

---

## 4. 资产计划（关键路径）

### 4.1 画布

- 设计画布 `720×960`：
  - `0…900`：猫、桌板、键盘、鼠标。
  - `900…960`：接触阴影，防止桌板底边被窗口裁断。
- 输出 `@2x` 1440×1920；`@1x` 作为低内存回退。
- App 只显示透明内容，**不含米色墙**。墙面只存在于设计板。

### 4.2 图层清单

| z | 文件 | 内容 | 备注 |
| --- | --- | --- | --- |
| 0 | `shadow@2x.png` | 桌板/猫接触阴影 | 可超出 900 |
| 1 | `table@2x.png` | 木桌板 | 无墙面、无杂物，边缘羽化 |
| 2 | `body@2x.png` | 身体、后腿、脚掌、尾巴 | 不含头、前臂 |
| 3 | `keyboard@2x.png` | 白键盘 | 不含猫爪 |
| 4 | `mouse@2x.png` | 白鼠标 | 右爪下方 |
| 5 | `head@2x.png` | 头、耳、脸颊、颈 | 不含瞳孔/眼睑 |
| 6 | `pupilL/R@2x.png` | 黑瞳 + 高光 | 在 head 组内平移 |
| 7 | `lidL/R@2x.png` | 眼睑 | 眨眼/眯眼 |
| 8 | `armL-rest/down@2x.png` | 左臂两态 | 肩点为轴 |
| 9 | `armR-rest/down/mouse@2x.png` | 右臂三态 | 按鼠标 |
| 10 | `keycap-blank@2x.png` | 空白键帽 | 字符运行时绘制 |

### 4.3 拆图步骤

1. 从 1373×1717 母版缩放到 1440×1800，底部补 120px 透明阴影区。
2. 去墙：只保留桌板轮廓、猫、键盘、鼠标、软阴影；桌板边缘 2px 羽化。
3. 用蒙版拆头/身体/手臂：
   - 头：耳尖到颈根，沿毛发 1–2px 羽化；颈根多留 18px 藏进身体。
   - 身体：去掉头与前臂；颈部和两腋补洞，重叠 ≥12px。
   - 手臂：按休息/落键/鼠标三张关键帧拆；肩点留 10px 身体色。
4. 瞳孔：从待机帧与右看帧提取黑瞳 + 高光，1px 羽化；虹膜/眼白留在 head。
5. 眼睑：从头部黑毛采样，闭合时覆盖整个眼球，边缘 3px 软过渡。
6. 透明区 RGB 归一到同色，避免缩放白边/黑边。
7. 2× 放大目检颈根、腋下、尾根、桌板底边；接缝 >2px 返工。

### 4.4 降级方案

- **A 级**：完整分层（头/瞳/眼睑/双臂）——目标。
- **B 级**：头/瞳/眼睑分层 + 整身姿态帧（休息/落键/鼠标）120ms 淡化——补洞失败时用。
- **C 级**：只上线“视线 + 头部微动 + 键帽”，姿态继续矢量——最差也能交付一部分。
- 不允许把 B/C 级写成“v4 已完成”。

### 4.5 授权

- 只打包自产或已确认可商用素材。
- 参考视频、DesktopCat、Hijiki、Co-Working Cat 素材**不进仓库、不进 App**。
- 设计板可留在 `Docs/design` 作为内部设计记录；README 截图只用自产实机图。

---

## 5. 坐标与锚点

```json
{
  "canvas": [720, 960],
  "contentHeight": 900,
  "anchors": {
    "headPivot": [360, 548],
    "headCenter": [360, 385],
    "eyeLeft": [245, 420],
    "eyeRight": [390, 420],
    "shoulderLeft": [252, 560],
    "shoulderRight": [475, 560],
    "keyboardRect": [60, 700, 650, 120],
    "mouseRect": [600, 742, 92, 68]
  },
  "keycapSlots": [
    [290, 145], [445, 95], [605, 165], [520, 190]
  ]
}
```

- 所有锚点写 `manifest.json`，Swift 只读，不散落硬编码。
- 旧 `PetRigLayout` 的 260×360 坐标通过 `PetV4Layout.mapFromLegacy()` 换算；新代码不混用两套坐标。
- 窗口尺寸：
  - 中号 `288×384`（内容 288×360 + 阴影 24）
  - 小号 `230×307`
  - 大号 `374×499`
  - 外圈 padding 4pt。

---

## 6. 视线与头部

### 6.1 全屏光标

当前问题：`normalizedMousePosition()` 用 `panel.frame` 中心归一化，光标稍微一动就到 ±1，眼睛像“开关”而不是跟随。

改为：

```swift
let cursor = NSEvent.mouseLocation
let screen = panelScreen
let head = panel.convertToScreen(headPoint)
let dx = cursor.x - head.x
let dy = cursor.y - head.y
let nx = clamp(dx / (screen.frame.width * 0.35), -1, 1)
let ny = clamp(dy / (screen.frame.height * 0.30), -1, 1)
```

- 宠物在副屏时，以宠物所在屏计算；光标在另一屏时自然饱和到边缘。
- 30Hz 采样，仅面板可见时运行。
- 不需要新权限。

### 6.2 映射表

| 输出 | 目标 | 弹簧 | 上限 |
| --- | --- | --- | --- |
| 瞳孔 X | `nx * 10px` | 700 / 40 | ±10px |
| 瞳孔 Y | `-ny * 6px` | 700 / 40 | ±6px |
| 头偏航 | `nx * 3°` | 240 / 28 | ±3°，鼻尖 ≤8px |
| 头俯仰 | `-ny * 2°` | 240 / 28 | ±2°，垂直 ≤4px |
| 身体侧倾 | `nx * 1°` | 220 / 28 | ±1° |

时间：

- 瞳孔 180ms 到 95%。
- 头延迟 120ms 启动，240ms 缓出到 90%。
- 不许头和瞳孔同一帧到目标。

### 6.3 防过度

- 头部绕 `headPivot (360,548)` 旋转；每帧检查鼻尖位移，>8px 自动降压。
- 俯仰不做真 3D：`translateY = -ny*3px` + `scaleY -= abs(ny)*0.004`。
- 光标贴近猫脸（距离 <120px）：瞳孔回中，头不追。
- 屏幕边角：头最多 4°，但渲染硬限仍是 3°；多余 1° 用 1px 平移吸收。

### 6.4 优先级

1. 打字（`activeKeys` 非空或 `typingUntil` 未到）：看当前键，头向键盘 1.5°。
2. 按鼠标（mouseDown 后 600ms）：看鼠标，头向鼠标 1.5°。
3. 默认：全屏光标。
4. 锁屏/Secure Input/休眠：冻结、回正。
5. `followMouse == false`：回中。
6. `reduceMotion`：取消头转/尾摆，只留瞳孔 0.12s 跟随与眨眼。

---

## 7. 姿态与落键

### 7.1 权重

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

| 状态 | 左 | 右 |
| --- | --- | --- |
| 待机 | rest 1 | rest 1 |
| 左/中区按键 | down 1 | rest 1 |
| 右区按键 | rest 1 | down 1 |
| 按鼠标 | rest 1 | mouse 1 |
| 左右同时按 | down 1 | down 1 |

- 120ms ease-out 过渡。
- 两层同时绘制，alpha 相加不为 1 时用 normal blend；down 层额外 `+2px` 遮双影。
- 不允许整猫换帧。

### 7.2 落键

- 非 repeat keyDown：`armDownYOffset 0 → +4px` 80ms，`+4 → 0` 120ms，过冲 -1px。
- 手臂纵向压缩 1.01，模拟爪垫压键。
- 身体只下沉 1px。
- 键帽同帧生成，不等手臂到位。

### 7.3 按鼠标

- 右臂 `armR_mouse` 0→1，140ms。
- 鼠标图层下沉 2px，松开 120ms 回弹。
- 头向鼠标 1.5°；不生成键帽。

---

## 8. 键帽

### 8.1 参数

| 阶段 | 时间 | 行为 |
| --- | --- | --- |
| 生成 | 0ms | 槽位下方 95px 出现，scale 0.85，alpha 1 |
| 弹出 | 0–80ms | 到槽位，scale→1.2 |
| 悬浮 | 80–420ms | 正弦微摆 ±4px |
| 淡出 | 420–600ms | 上浮 18px，alpha→0 |

- 最多 4 个；第 5 个移除最旧。
- 槽位固定：`(290,145) (445,95) (605,165) (520,190)`。
- 起点在头顶后方，不穿脸、不穿胸。
- 字符取 `PetKeyMap.label`，英文大写；修饰键 `⌘ ⇧ ⌥ ⌃ fn`。
- 字符用 `GraphicsContext.draw(Text)` 叠在 `keycap-blank` 上，和键帽同一 transform。
- 小号字号 ≥9pt；长标签自动降字号。
- 不记录文本、不写日志、不持久化。

### 8.2 防叠

- 淡出中的键帽仍占槽。
- 新键帽优先空槽；无空槽时移除最旧并立即占用。
- 连打 60ms 不出现两个键帽同一位置。

---

## 9. 时钟与性能

- 活动：30fps，keyDown/mouseMove/mouseDown 触发 0.9s 爆发。
- 跟随：15fps，0.9s 后仍有光标移动。
- 静止：2fps，只跑呼吸/眨眼。
- `reduceMotion` / 低电量：15fps，禁头转/尾摆。
- 隐藏/锁屏/录制隐藏：停止 30fps。
- `Canvas` 图层预解码缓存；不逐帧创建 `NSImage`。
- 目标：静止 CPU <3%，活动 <8%，内存 <80MB，1 小时无增长。

---

## 10. 代码改动清单

新增：

```text
Sources/MacAppControlDeck/Modules/Pet/PetV4/
├── PetV4Layout.swift
├── PetV4Manifest.swift
├── PetV4AssetStore.swift
├── PetV4Rig.swift
├── PetV4Canvas.swift
└── PetV4KeycapRenderer.swift

Sources/MacAppControlDeck/Modules/Pet/Resources/PetV4/
├── manifest.json
└── *.png
```

修改：

| 文件 | 改动 |
| --- | --- |
| `PetTypes.swift` | 增加 `PetRenderStyle`、`headPitch`、`ArmWeights`、4 槽键帽字段；旧字段给默认值 |
| `PetStateMachine.swift` | 全屏光标方向、头角度硬限、4 槽/0.6s、30fps 状态；保留旧 `handleMouseMoved` |
| `PetAnimationClock.swift` | 20fps→30fps；加 15fps 档 |
| `PetSceneView.swift` | 按 `renderStyle` 选 v4/矢量 |
| `PetGeometry.swift` | v4 窗口/视觉尺寸、底部锚点 |
| `PetSettingsView.swift` | 补一句“黑猫 v4 / 其他皮肤矢量” |
| `Package.swift` | `.copy("Modules/Pet/Resources")` |
| `README.md` | v4 行为、尺寸、透明场景、已知限制 |

兼容：

- `PetSettings.skinID` 不变，只有 `midnight-black` 走 v4。
- `pet.renderV4` 默认 true；资产校验失败本次会话回退。
- 已保存位置按归一化恢复后 clamp，不跳屏。
- 旧 `headYaw` 语义从 -1…1 改为角度 -3…3；矢量渲染乘 2.33 保持旧幅度。

---

## 11. 里程碑与工期

| 阶段 | 内容 | 工期 | 依赖 | 交付 |
| --- | --- | --- | --- | --- |
| M0 | 基线整理 + OpenSpec | 0.5d | 无 | 分支、变更、基线测试 |
| M1 | 拆图/补洞/manifest | 2–3d | M0 | 14 张透明 PNG + 校验 |
| M2 | 渲染骨架静态 | 2d | M1 | 实机透明待机、三档 |
| M3 | 全屏视线/头 | 1d | M2 | 眼/头连续跟随 |
| M4 | 姿态混合 | 1–2d | M2 | 打字/鼠标动作 |
| M5 | 键帽 | 1d | M4 | 4 槽/0.6s/字符 |
| M6 | 时钟/生命周期/性能 | 1d | M5 | 30fps、降级 |
| M7 | 验证/文档/归档 | 1–2d | M6 | 构建、截图、归档 |

**合计 9–12 个工作日。** 关键路径是 M1；M1 不过，后面不排。

建议检查点：

- CP1（M1 结束）：静态透明图与主视觉并排，接缝 ≤2px。
- CP2（M3 结束）：录 10 秒屏幕，眼先到头后到，四角不甩头。
- CP3（M5 结束）：录 10 秒连打，键帽字符正确、最多 4 个、不叠脸。
- CP4（M7 结束）：安装包实机 1 小时，CPU/内存达标。

---

## 12. 验收清单

### 视觉

- [ ] 透明桌面，无米色墙、无矩形底、无白边。
- [ ] 黑猫与已确认主视觉一致：大绿眼、右侧 C 弧尾、木桌、白键盘/鼠标。
- [ ] 三档尺寸耳尖/尾巴/桌板/鼠标不裁切。
- [ ] 颈根、腋下、尾根 2× 放大接缝 ≤2px。
- [ ] 头部 ±3° 不露颈、不甩耳、鼻尖 ≤8px。

### 交互

- [ ] 光标屏幕四角：眼 180ms 到，头 120ms 后跟随，身体基本不动。
- [ ] 光标贴近脸：瞳回中，头不追。
- [ ] 打字：双爪落键盘、键帽带真实字符、0.6s 消失、最多 4 个。
- [ ] 按鼠标：右爪压鼠标、头偏 1.5°、不生成键帽。
- [ ] 连打 60ms：手臂不抖、键帽不叠。
- [ ] 关闭 `followMouse`：回中，打字/鼠标仍工作。
- [ ] Reduce Motion：无头转/尾摆，只留瞳与眨眼。

### 稳定性

- [ ] 无输入监控权限：仍显示、眨眼、跟随鼠标，不响应键盘。
- [ ] Secure Input / 锁屏 / 休眠：冻结回正，恢复不补键帽。
- [ ] 隐藏/重开：窗口、监听、时钟释放。
- [ ] 资产缺失：自动回退矢量，不崩溃。
- [ ] 五套皮肤切换：非黑猫不受影响。
- [ ] 点击穿透 / hover 命中：桌板与猫轮廓正确。
- [ ] 1 小时 CPU/内存无异常。

### 工程

- [ ] `swift test` 全绿。
- [ ] `./Build/build.sh` release 签名成功。
- [ ] `/Applications/MacAppControlDeck.app` 覆盖安装后可启动。
- [ ] README/Docs/OpenSpec 归档完成。
- [ ] 提交说明引用 `add-desktop-pet-v4-raster-rig`。

---

## 13. 风险与对策

| 风险 | 概率 | 影响 | 对策 |
| --- | --- | --- | --- |
| 补洞露缝 | 高 | 高 | 2× 目检；失败走 B 级整身姿态帧 |
| 头旋转露颈 | 高 | 高 | 颈根多留 18px、胸口填底、角度硬限 |
| 透明场景不如设计板 | 中 | 中 | 桌板 2px 羽化 + 软阴影；不放墙 |
| 30fps Canvas CPU 高 | 中 | 中 | 图层缓存、活动才 30fps、空闲 2fps |
| 多屏坐标错 | 中 | 中 | 以宠物所在屏计算，四角/副屏单测 |
| 与未提交 V2 冲突 | 中 | 中 | 先提交/stash，再开分支 |
| 字体在键帽上旋转发虚 | 低 | 低 | 字符单独渲染，按 2x 画布；必要时预生成 96 个字符纹理 |
| 素材授权 | 中 | 高 | 只用自产；参考素材不进包 |

---

## 14. 不在本次范围

- 狗皮肤、白猫/橘猫/三花栅格化。
- Live2D/Cubism、3D 引擎、骨骼网格。
- 逐帧 AI 生成动画。
- 新的输入监控权限、读取输入文本、联网。
- 新模块或新打开按钮；沿用 `pet.open`、`⌃⌥P`、菜单与设置页。
- App Store 沙盒适配。

---

## 15. 开工顺序（可直接照做）

1. `git status` → 当前改动单独提交/stash → 开分支。
2. 建 `openspec/changes/add-desktop-pet-v4-raster-rig/`（已建好）。
3. 做 M1 资产：先出静态透明合成图，CP1 通过再写 Swift。
4. 写 `PetV4Manifest` / `AssetStore` / `Layout`，实机静态显示。
5. 接全屏光标与头/瞳，录 CP2。
6. 接手臂权重与键帽，录 CP3。
7. 升 30fps、做降级、跑测试与性能。
8. 截图、README、归档、提交。
