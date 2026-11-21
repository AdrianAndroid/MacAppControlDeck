# 桌面宠物 v4 · 分层素材规格

> 对应变更：[`add-desktop-pet-v4-raster-rig`](../../openspec/changes/archive/2026-11-21-add-desktop-pet-v4-raster-rig/proposal.md)
> 资源目录：`Sources/MacAppControlDeck/Modules/Pet/Resources/v4/`
> 生成脚本：`/tmp/petv4/scene_assets.py`（仓库根目录执行，源图 `Docs/design/clean-desktop-pet-v4-desk-keyframe.png`）
> manifest：`Resources/v4/manifest.json`（运行时只读它，不读死值）

## 1. 设计坐标系

- 设计画布 **720 × 960**（逻辑 pt），y 轴向下，原点左上。
- 素材统一按 **2x** 出图，渲染时 `scaleBy(width / 720)` 缩放，整数坐标落点。
- 所有 origin / box / neck / slot 坐标都写在 manifest 的 **2x 像素空间**里，渲染器先按 2x 绘制再整体缩放。

## 2. 图层与 z 序

| z | 图层 | 文件 | 尺寸 | 说明 |
|---|------|------|------|------|
| 0 | 场景 | `scene.png` | 1440 × 1220，origin (0, 700) | 木桌 + 桌面淡出 + 猫身（去墙），底部 alpha 垂直斜坡淡出到透明 |
| 1 | 头部 | `head.png` | 692 × 543，origin (313, 435) | 头部剪影 + 挖空的两个眼窝（填 `(30,28,26)`） |
| 1 | 左眼 | `eyeL.png` | 眼窝外扩 1.7 倍椭圆裁剪 | 与头同层绘制，保证旋转时不错位 |
| 1 | 右眼 | `eyeR.png` | 同上 | |
| 2 | 键帽 | `keycap.png` | 90 × 80 | 白键帽底 + 顶面，字母用 `Canvas` 文字叠加 |

顺序：`scene → head(绕 neck 旋转 yaw + 平移 bob/headPitch, 再画两只眼) → keycaps`。

## 3. 关键坐标（2x 像素）

| 名称 | 值 | 说明 |
|------|----|------|
| designSize | 720 × 960 | 逻辑画布 |
| scale | 2 | 素材倍率 |
| scene | origin (0,700), size 1440 × 1220 | 覆盖桌面以下 |
| head | origin (313,435), size 692 × 543 | 头部 bbox |
| neck | (450, 962) | 头部旋转支点 |
| eyes.left.box | (361, 683) | 左眼绘制原点（外扩后） |
| eyes.right.box | (590, 664) | 右眼绘制原点（外扩后） |
| 眼中心 | L (469,786) / R (712,773) | 用于校核瞳孔基准 |
| pupilRange | x 20 / y 12 | 瞳孔位移上限（2x 像素） |
| 头部旋转 | yaw 3° / pitch 2° | 上限 |
| 键帽槽位 | [[600,300,-5],[905,205,4],[1200,330,-3],[1030,390,3]] | x, y, 旋转角度 |
| riseY | 200 | 淡出阶段上浮距离（2x 像素） |
| life | 0.6 s | 单个键帽生命周期 |

参考辅助线（用于核对素材与排版）：

- 键盘多边形：`(126,1285),(988,1328),(1002,1366),(985,1470),(955,1512),(700,1524),(300,1520),(140,1495),(124,1400),(120,1340)`
- 鼠标 bbox：1063..1242 / 1411..1505
- 桌面线：`y = 1278 + 0.0146 * x`

## 4. 生成规则（复跑要点）

1. 源图 1373 × 1717 → 画布 1440 × 1920，缩放 S = 1440 / 1373 = 1.0488；`Image.paste` 的 mask 必须与 source 同尺寸，统一改「全画布 layer + alpha 相乘」。
2. 猫 alpha：`lum < 145` 闭运算 → floodfill 填洞 → 取 `min((180-lum)/60)` 亮度 ramp；洞内抬到 0.90。橘色键帽会污染 alpha，必须 `orange ∩ kbRegion` 限定区域后再减。
3. 场景 alpha 去墙：`scene_al = (1 - above) + 0 * lum`，并用 `alpha * 1.6` 抬猫剪影；底部加 `ramp = clip((1800 - y) / 180, 0, 1)` 淡出原有灰色地面。
4. 头部多边形 `HEAD_POLY`（feather 1.5）∩ `alpha > 0.5` 得 headSolid，在头图层内挖两个椭圆眼窝填 `(30,28,26)`。
5. 不做「毛发边缘膨胀」：41px 膨胀会在墙上留灰光晕与直线接缝，body 直接用原始 base，旋转露出的像素天然无缝。
6. 预览合成 `1920` 行画布与 `1800` 行蒙版会 broadcast 报错，用 `np.pad` 对齐。

## 5. 运行时参数（Swift）

| 参数 | 值 | 位置 |
|------|----|------|
| 窗口尺寸 | 288 × 384（中档），三档 230×307 / 288×384 / 374×499 | `PetGeometry` / `PetSize.scale` 0.8 / 1.0 / 1.3 |
| 帧率 | 悬停 1/30 s，空闲收敛到弹簧静止 | `PetAnimationClock` |
| 眼球弹簧 | ±10 / ±6 pt，stiffness 520，damping 34 | `PetStateMachine` |
| 头部弹簧 | yaw ±3° / pitch ±2.2°，stiffness 150，damping 26 | 同上 |
| 呼吸浮动 | `sin(t * 1.35) * 1.6` pt | 同上 |
| 打字视线下压 | gazeY + 0.22 | 同上 |
| 键帽 | 0.6 s 生命周期、4 槽、0–80ms 升起 / 80–420ms 悬浮 / 420–600ms 上浮淡出，字号 17pt semibold，颜色 `(0.20,0.18,0.17)` | `PetRasterRenderer` |
