# 任务清单：add-desktop-pet-v6-full-body-rig

> 状态：已交付（2026-11-21）。实现口径以 `Docs/design/desktop-pet-v6-layer-spec.md` 为准；
> 落键采用「单骨前臂 + 肩轴旋转 + push/slide 跟列」，未采用原计划中的两段解析 IK（单层前臂素材无法拆分肘关节，详见 design.md「偏离记录」）。

## 0. 变更与设计

- [x] 0.1 `proposal.md` / `design.md` / `tasks.md` / spec delta 落盘
- [x] 0.2 设计稿 `Docs/plans/2026-11-21-desktop-pet-v6-full-body-rig.md` 与本文口径对齐

## 1. P0 三张干净母版

- [x] 1.1 keyboard-only：`image_gen` + transparent 独立出图，空白键帽、两端各一颗橙键、不裁底边
- [x] 1.2 mouse-only：`image_gen` 独立出图，扁平极简白鼠，保留滚轮缝与高光
- [x] 1.3 cat-only：`image_edit` 以 v4 母版为参考去掉桌子与键鼠，纯白底，姿态不变
- [x] 1.4 三张统一到 1440×1920 画布，按「键盘前沿线 + 爪印」对齐
- [x] 1.5 抠图验收：2× 目检键盘底边、鼠标轮廓、猫身轮廓无残边 / 无洞（含 unpremultiply 去白晕、y>950 反光带清零）

## 2. P1 解剖分层

- [x] 2.1 头 / 双耳 / 颈补片
- [x] 2.2 躯干（含臀腿，保留整只猫真实像素，仅补眼窝）
- [x] 2.3 前臂 L/R（整条臂含爪，绕肩轴）
- [x] 2.4 尾巴两段
- [x] 2.5 眼（虹膜 / 瞳孔独立层，眼睑程序化）
- [x] 2.6 `manifest.json` v6：designSize / scale / canvas / order 17 项 / rig / keyboardGrid
- [x] 2.7 静止合成与母版差异目检通过（`v6_pose_board.png` 三姿态无接缝）
- [x] 2.8 接缝策略改为 `grown()`（dilation 12 + blur 3），消除直线白缝

## 3. P2 绑定与驱动（替代原 IK 方案）

- [x] 3.1 躯干坐标系：torso → tail1/tail2 → armL/armR → neck → head → earL/earR → iris/pupil
- [x] 3.2 图层单位统一：`pt()` = asset px / scale（manifest box 与 rig 单位不再混用）
- [x] 3.3 键位列 → 键盘网格坐标 → 该侧手臂跟列（`clamp(keyX - pawHome, ±32)`，0.6s 回落）
- [x] 3.4 单测：躯干倾斜必须带动头/臂/尾；单臂整条运动；尾段相位滞后；键帽弹起高度

## 4. P3 运动语法（全身参与）

- [x] 4.1 按键：该侧臂旋转 + 下压 26pt + 跟列、键帽 85pt、躯干前倾、颈低头、耳压、尾加速度
- [x] 4.2 光标：yaw ±8° / pitch ±4°、虹膜 ±11.6/7.4、瞳孔 ±13.7/8.4、躯干随视线倾 ±3.4°
- [x] 4.3 鼠标按下：右臂落到鼠标上方、鼠标下沉 2pt + 轻微压扁、躯干右倾
- [x] 4.4 常驻：呼吸、眨眼、尾摆（段1 ±7°，段2 相位 0.18s）、耳抽动
- [x] 4.5 双键同时：双臂各自跟各自列，躯干前倾不叠加翻倍
- [x] 4.6 对照图：`/tmp/gaze_cmp.png`、`/tmp/ty_cmp.png`、`/tmp/w2_cmp.png`、`Docs/images/readme/desktop-pet-{hero,gaze,keycaps}.png` 已用 v6 实机截图重做

## 5. P4 键帽

- [x] 5.1 升起 85 设计 pt（屏上约 34pt）、生命 0.8s（0.18 快弹 / 0.62 悬停 / 回落淡出）、字号 12pt
- [x] 5.2 键帽与爪跟列同源（同一 `colStartX / colGap` 网格函数）
- [x] 5.3 键帽加光带投影，`slot%2` 决定 ±2.5° 歪斜，画在键盘之后、猫之前

## 6. P5 验收与收口

- [x] 6.1 `swift test` 全绿：111 项 0 失败（含 `PetV6RigTests` 8 项）
- [x] 6.2 release 构建 + 自签名 + 覆盖安装 `/Applications`
- [x] 6.3 实机连拍（idle / 光标左 / 光标右 / 打字两帧 / 单窗口），逐图对照「全身参与」清单
- [x] 6.4 README / v6 分层规格 / 归档摘要 / `openspec/specs` 同步
- [x] 6.5 归档到 `openspec/changes/archive/2026-11-21-add-desktop-pet-v6-full-body-rig/`
- [x] 6.6 提交说明引用 change-id；R0 写明沿用 `pet.open`，无新增用户可见入口

## 7. 回滚

- [x] 7.1 删除 `Resources/v6` 即回退 v5（`PetRasterRenderer` 按优先级 v6 → v5 → v4 → 矢量），设置不丢
- [x] 7.2 v5 资源保留一个发布周期
