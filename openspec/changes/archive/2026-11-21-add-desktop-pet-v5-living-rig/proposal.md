# 提案：桌面宠物 v5 Living Rig（去桌面 + 共视双眼 + 落爪姿态）

## Why

v4 已把定稿主视觉落成分层栅格并跑通，但实机看下来有三处与"生动"差得比较远：

1. **两只眼是分开动的**：左右眼是两张独立 PNG，各按同一屏幕向量平移；素材本身尺寸不同（左 60×57 / 右 68×61）、瞳孔基准不同，且没有共视点、没有眼睑、没有微扫视。视觉上是"两块贴片在各自滑"，不是"一双眼睛在看东西"。
2. **桌面突兀**：scene 层带着整张木桌，桌面左右被窗口裁断，看起来像被切断的图片，而不是贴在桌面上的角色。
3. **没有落爪 / 按鼠标姿态**：计划里的 `armR-mouse` 与落键姿态因三张关键帧不对齐（2x 下垂直错位 106px、桌面线差 35px、鼠标帧只有一只眼）被收敛掉了，改成"只动头和键帽"。结果是打字时爪子完全不动，因果断了。

此外还有三处生命感缺失：没有眨眼、尾巴与耳朵全程静态、键帽从头顶后方弹出而不是从键位升起；打字时视线固定下压 0.22，不落到真实按键。

本变更在不引入 Live2D / 3D 的前提下，用**更细的分层 + 局部精灵 + 统一视线向量**把这三件事补齐。

## What Changes

- **去桌面**：新拆层为 `shadow / keyboard / mouse / body / tail / head`，木桌像素全部剔除，猫身下缘沿键盘上沿 24px feather 淡出，键盘层在猫身前遮住下缘，无横向截断线。
- **视线改为唯一真源**：新增 `GazeVector`（归一化 3D 方向），每只眼按自己的 `EyeGeometry`（眼心 / 半径）做球面投影得到瞳孔偏移，头部 yaw/pitch 参与投影修正 ⇒ 两眼"各走一点、始终看向同一点"（夹角 < 1.5°）。
- **眼睑与眨眼**：新增 `lidL/lidR` 上眼睑图层，110ms 眨眼曲线，3–7s 随机，双眼同相位；睡眠时半闭 0.65。
- **微扫视与高光**：每 1.2–3.5s 一次 ±0.08 高频小位移；高光按 `-0.32 × pupilOffset` 反向微移。
- **头部幅度**：yaw ±3° → ±6°，pitch ±2.2° → ±3.2°，弹簧 150/26 → 190/28，视觉滞后 40ms（先眼后头）。
- **落爪姿态**：`pawL/pawR` 局部精灵 + `patchL/patchR` 补洞，做 rest / down / mouse 的 translate + rotate + squash；键盘对应键位下沉 1px、身体只 sink 1px。
- **生命感**：`tail` 绕尾根 ±4° 低频 + 偶发甩尾，`earL/earR` 每 8–20s 抽动；`body` 呼吸 scaleY 1.008。
- **键帽因果**：槽位从头顶后方改为**键盘键位上方**，`riseY` 90（2x），打字视线落到真实键位坐标。
- 版本隔离：新资源目录 `Resources/v5`，`PetRasterAssets` 按版本探测；删除 v5 即回退 v4。

**非目标**：

- 不做整帧序列动画、不做 AI 逐帧生成；所有运动仍由图层变换 + 弹簧驱动。
- 不引入 Live2D / 3D / 骨骼网格变形。
- 不改变输入监听权限模型、不记录按键文本、不联网。
- 不新增用户可见模块或新的打开按钮；沿用 `pet.open`、`⌃⌥P`、菜单与设置页。
- 不重做五套矢量皮肤（仍是素材缺失时的兜底）。

## Capabilities

### New Capabilities

- `desktop-pet-v5-family`：去桌面分层、共视双眼与眼睑、局部爪子姿态、尾巴/耳朵/呼吸生命感、键帽与键位因果。

### Modified Capabilities

- `desktop-pet`：v4 的"单帧场景与头部/键帽反馈"要求被 v5 的"分层场景 + 局部姿态"取代；"事件键帽与真实字符"新增"从键位升起"约束；"全屏视线跟随"新增共视夹角与眨眼约束。

## Impact

- 代码：`PetRasterRig.swift`（渲染器与 manifest 结构扩展）、`PetStateMachine.swift`（GazeVector / EyeState / PawState / 眨眼与扫视）、`PetGeometry.swift`、`PetSettingsView.swift`（说明文案）、`PetPanelController.swift`（打字键位映射）。
- 资产：`Sources/MacAppControlDeck/Modules/Pet/Resources/v5/`（新目录）；`Docs/design/` 增加眼睑、爪子、补洞的中间产物。
- 测试：新增 ≥ 8 组，既有 90 项保持全绿。
- 文档：README 桌宠章节、`Docs/design/desktop-pet-v5-layer-spec.md`、`Docs/archive/2026-11-21-desktop-pet-v5/SUMMARY.md`。
- 性能：合成层数由 3 增至 8，30fps 活动期 CPU 目标 < 8%（含 shadow/keyboard 预合成静态底图兜底方案）。
