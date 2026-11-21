# 桌面宠物 v6 分层与骨骼规格（Full-Body Rig）

> 适用代码：`Sources/MacAppControlDeck/Modules/Pet/PetRasterV6.swift`（资产/渲染）、`PetRasterRig.swift`（帧字段与分发）、`PetStateMachine.swift`（运动语法）
> 资产目录：`Sources/MacAppControlDeck/Modules/Pet/Resources/v6/`
> 生成脚本：`Docs/design/pet-v6-build-assets.py`（仓库根执行，全量重建 17 层 + manifest）
> 设计稿：[`Docs/plans/2026-11-21-desktop-pet-v6-full-body-rig.md`](../plans/2026-11-21-desktop-pet-v6-full-body-rig.md)

## 1. 与 v5 的根本区别

| 维度 | v5「局部微动」 | v6「全身绑定」 |
| --- | --- | --- |
| 分层 | 18 层，但躯干是一整块、手臂只有「爪」 | 17 层，含躯干 / 颈 / 头 / 双耳 / 双前臂 / 两段尾 / 双鼠键 |
| 坐标系 | 各层各自绕自己的中心动 | 一个**躯干坐标系**串住尾巴 → 双臂 → 颈 → 头 → 耳 → 眼，躯干动则全身跟着动 |
| 振幅口径 | 设计 px 小值（屏上缩到不足 3pt） | 全部按「屏上 ≥3pt 可感知」定标，头 8° / 躯干 3.5° / 尾 7° / 键帽 85 设计 pt（屏上 ~34pt） |
| 母版 | 从带桌子的合成图抠 | 猫 / 键盘 / 鼠标**三张独立干净母版**，透明底或纯白底，各自抠图 |
| 键帽 | 字符贴图 + 6px 浮起 | 真实键盘网格坐标 + 85 设计 pt 三段式弹起，光带投影 |

## 2. 三张母版

| 文件 | 尺寸 | 底色 | 来源 |
| --- | --- | --- | --- |
| `v6-cat-master.png` | 1373×1717 | 纯白 | `image_edit` 以 v4 母版为参考，姿态/毛色/爪位不变，去掉桌子与键鼠 |
| `v6-keyboard-master.png` | 2379×991 | 透明 | `image_gen`（seedream_5.5 + transparent）：奶油白矮轴、**空白键帽**、两端各一颗橙键 |
| `v6-mouse-master.png` | 1773×1330 | 透明 | `image_gen`：极简扁平纯白无线鼠标，滚轮缝清晰 |

设计画布 720×960 pt，资产 2x（1440×1920 px）。`CAT_SCALE=1.05`、`CAT_DY=92`、`CAT_DX=1440/2-1373*1.05/2` 把猫对齐到画布；键盘 `KB_W=1000`、`KB_TOP=1466`；鼠标宽 236 靠右。

## 3. 17 层与 pivot

`layers` 是**名字 → 资产**的字典；`pivot` 是**裁切后 local asset px**，`rig` 里的坐标是**design pt**。两者单位不同，Swift 侧统一 `pt()`（= /2）换算，混用会让图层绕错误的圆心转动。

| 层 | 内容 | pivot 依据 | 画序 |
| --- | --- | --- | --- |
| `shadow` | 柔和接触阴影（椭圆 0.42 alpha） | — | 0（最底） |
| `keyboard` | 整块键盘 + 光带投影 | box 左上 | 1 |
| `keycap` | 单键帽模板 62×74 px，运行时按网格复制 | 帽心 | 2 |
| `tail1` / `tail2` | 尾巴两段，段2 叠在段1 内 | `tailRoot` / `tailMid` | 3–4 |
| `mouse` | 完整鼠标（不拆左右键） | 底心 | 5 |
| `torso` | **整只猫的真实像素**，只把眼窝 socket 补成毛色 | `hip` | 6 |
| `armL` / `armR` | 整条前臂 + 爪（含肩部覆盖） | `shoulderL` / `shoulderR` | 7–8 |
| `neck` | 下颌/颈部真实像素条带，补头转动时的拼接缝 | `neck` | 9 |
| `head` | 头（**耳朵烘焙像素**沿耳尖走） + 眼白 | `neck` | 10 |
| `earL` / `earR` | 双耳独立层，叠在头上 | `earLBase` / `earRBase` | 11–12 |
| `iris_l/r` | 虹膜，锚定在 `eyeL/eyeR`，偏移 clamp 到 `r*0.34` | 虹膜中心 | 13,15 |
| `pupil_l/r` | 瞳孔，在虹膜偏移上再追一段，clamp 到 `r*0.62` | 瞳孔中心 | 14,16 |

`torso` 之所以保留整只猫像素而不是「补毛填充」：多边形扩散填充出来的毛色和真实毛色不一致，会在接缝处出现横平竖直的浅色块；保留真实像素 + 相邻层外扩覆盖（`grown()`：hard polygon 先 `binary_dilation(12)` 再 `blur(3)`）能做到任何层转动都不露白、也不出现旧眼睛。

## 4. 骨骼与 rig 常量（design pt）

```text
hip(314.6,697) ─ tailRoot(507.8,693.9) ─ tailMid(583.4,699.1)
 └ neck(314.6,577.3)
    ├ head            yaw ±8°，pitch ±4°
    │  ├ earLBase(246.3,391.4)  earRBase(387,391.4)   twitch 6°
    │  └ eyeL(242.1,457.6) r(36.8,39.9) / eyeR(368.1,448.2) r(36.8,39.9)
 │     gazeRange(11.6,7.4)  pupilRange(13.7,8.4)
 ├ shoulderL(264.7,571) → pawL(242.1,728.5)   armSwing 9°
 └ shoulderR(389.1,583.6) → pawR(367.1,675)   armSwing 9°
torsoLean 3.5°   torsoBreathe 0.008
keycapRise 85    keycapLife 0.8s
```

键盘网格（design pt）：`box=[100,733,500,207.5]`、`backRowY=792`、`rowGap=38`、`colStartX=133`、`colGap=33.4`。

## 5. 渲染顺序（一帧）

1. `shadow`（缩放 1.0 + 呼吸微缩放，alpha 0.42）
2. `keyboard`
3. `keycap × N`（弹起中的键帽，先于猫画，猫爪自然压在键帽前面）
4. `mouse`（`mousePress` 时下沉 2pt + 轻微压扁）
5. **躯干坐标系**（平移/旋转到 hip，再按 torsoDeg/torsoLift）：
   `torso → 尾巴两段 → armL/armR → neck → head → earL/earR → iris/pupil`
   - 尾巴：段1 绕 `tailRoot` 转 `tail1Deg`；段2 以 `tailMid` 为轴，按 `tail2Deg` 叠加在段1 的已变换坐标系内
   - 手臂：绕肩轴旋转 `armLDeg/armRDeg` + 沿臂向下 `armLPush/armRPush` + 横向 `armLSlide/armRSlide`
   - 头：绕 `neck` 旋转 `headYaw/headPitch`；耳在头坐标系内各自绕耳根转 `earLDeg/earRDeg`

## 6. 运动语法（v6）

| 输入 | 全身响应 |
| --- | --- |
| 光标移动 | 虹膜 `±11.6/7.4` + 瞳孔再追 `±13.7/8.4` + 头 yaw `±8°/pitch ±4°` + 躯干倾 `(gazeX-0.2)*3.4` |
| 按键（左区/右区） | 该侧臂旋转 + 下压 26pt + **横向跟到该键列**（`clamp(keyX - pawHome, ±32)`）+ 该侧键帽弹起 85pt；躯干前倾、颈低头、耳后压、尾巴加速度摆动 |
| 同时双按 | 双臂各自跟各自列，躯干前倾不翻倍 |
| 鼠标按下 | 右臂下压到鼠标上方、鼠标下沉 2pt、躯干右倾 |
| 静止 | 呼吸 `sin(t/4.2*2π)` → 躯干升降，尾巴 `sin(t*1.36)*5.2` 与段2 `sin((t-0.18)*1.36)*7.4`（0.18s 相位差），耳随机抽动，眨眼 4.2s |

`reduceMotion` 打开时全部振幅归零，只保留键帽与状态切换。

## 7. 验收口径

- `swift test`：111 项（含 `PetV6RigTests` 8 项：分层齐全 / pivot 合理 / 躯干带动头手尾 / 单臂整条动 / 尾段相位 / 键帽弹起 / 虹膜瞳孔共视 / 呼吸不过猛）
- 实机：大档 374×499，屏上键帽升起约 34pt、头偏 8°、瞳孔横移约 6pt，正常观看距离肉眼可辨
