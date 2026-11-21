# 桌面宠物 v4（光栅分层 · 单帧场景）归档摘要

- change-id：`add-desktop-pet-v4-raster-rig`
- 日期：2026-11-21
- 计划：`Docs/plans/2026-11-21-desktop-pet-v4-landing.md`
- 分层规格：`Docs/design/desktop-pet-v4-layer-spec.md`

## 做了什么

- 从用户认可的 v4 主视觉（`Docs/design/desktop-pet-v4-desk-keyframe.png`）拆出一套 2x 分层素材：`scene`（木桌 + 白键盘 + 白鼠标 + 猫身，去墙）、`head`（含挖空眼窝）、`eyeL`/`eyeR`、`keycap`，加 `manifest.json` 描述坐标与参数。
- 新增 `PetRasterRig.swift`：`PetRasterManifest` 解码、`PetRasterAssets` 懒加载（多候选路径，失败整体回退矢量）、`PetRasterRenderer` 每帧按 z 序合成（scene → head 绕颈部旋转/平移并画双眼 → 键帽）。
- 状态机改造：新增 `rasterFrame` 与 `gazeCursorX/Y`、`handleGaze(normalizedX:normalizedY:)`；四条光栅弹簧（瞳孔 ±10/±6pt、头 yaw ±3°/pitch ±2.2°、呼吸 1.6pt），打字时视线下压 0.22。
- 全屏视线：`PetPanelController.normalizedGazePosition()` 用宠物所在屏的 `visibleFrame` 归一化 `NSEvent.mouseLocation`，在 30fps hover 定时器里和 `normalizedMousePosition()` 一起喂状态机。
- 键帽：4 槽 / 0.6s 生命周期（0–80ms 升起、80–420ms 悬浮、420–600ms 上浮淡出），帽面叠加真实字符（`PetKeyMap.label`），颜色 `(0.20,0.18,0.17)`、17pt semibold。
- 尺寸与命中区：基准 260×360 → 288×384，三档 0.8/1.0/1.3 = 230×307 / 288×384 / 374×499；六个命中区域按 v4 版面重写。
- 接入：`PetSceneView`、`PetLivePreview` 有素材走光栅；`PetSettingsView` 有素材时隐藏皮肤/键盘主题，改为一行说明；`PetModule` 有素材时不插入换肤菜单；`Package.swift` 打包 `Resources/v4`；`PetAnimationClock` 活动帧率 1/30。

## 关键决策与偏差

- **放弃三帧整场景混合**：`idle` / `typing-down` / `mouse` 三张关键帧彼此不对齐（眼中心与桌面线在 2x 下差 106px / 35px，`mouse` 帧只有右眼），交叉淡化会双影 + 跳变。改为**单帧场景 + 头部/眼球独立运动**，原计划的 `armR-mouse` 与落爪姿态切换不做；键帽即落键反馈，按鼠标只做头偏。
- **不做毛发膨胀 margin**：41px 膨胀会在墙上形成灰光晕与直线接缝，`body` 直接用原始 base，旋转露出的像素天然无缝。
- **键帽字母必须后置绘制**：`alpha` 提取时橘色键帽会污染蒙版，必须用 `orange ∩ kbRegion` 限定区域后再减。

## 验证

- `swift test`：90 项 0 失败（几何、状态机、键帽、三档尺寸、命中区、设置页渲染）。
- `./Build/build.sh` release + 自签名通过，覆盖安装 `/Applications/MacAppControlDeck.app`。
- 实机：深色桌面透明渲染正常（无墙、无矩形底、底边自然淡出）；`CGWarpMouseCursorPosition` 把光标移到屏幕左/右，瞳孔与头部偏转正确；`CGEventPost` 连按 ⌘/⇧ 后截到 4 个带字符键帽。

## 边界与回滚

- 有 v4 素材时桌宠固定为黑猫，五套皮肤 / 键盘主题入口收起；素材缺失整条链路回退矢量皮肤，行为与 v4 前一致。
- 眨眼仍走矢量逻辑（v4 未做闭眼图层）。
- 删除 `Resources/v4` 即可整体回滚，不丢用户设置，编译不受影响。
- R0：沿用已有内置入口 `pet.open`（`BuiltinActions.swift` → `PetModule.shared.open()`），未新增按钮。
