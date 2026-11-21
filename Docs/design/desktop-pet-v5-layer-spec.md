# 桌面宠物 v5「Living Rig」· 分层素材规格

> 对应变更：[`add-desktop-pet-v5-living-rig`](../../openspec/changes/archive/2026-11-21-add-desktop-pet-v5-living-rig/proposal.md)
> 资源目录：`Sources/MacAppControlDeck/Modules/Pet/Resources/v5/`
> 生成脚本：`Docs/design/pet-v5-build-assets.py`（仓库根目录执行，源图 `Docs/design/clean-desktop-pet-v4-desk-keyframe.png`）
> manifest：`Resources/v5/manifest.json`（运行时只读它，不读死值）

## 1. 与 v4 的差别

| 项 | v4 | v5 |
|----|----|----|
| 场景 | `scene.png` 含整张木桌，alpha 按「桌在底下」抠 | 完全去桌子，只剩 `shadow / keyboard / mouse` 独立层 |
| 眼睛 | 左右眼各一张 PNG，同向量平移，无眼睑 | 虹膜固定、瞳孔共视偏移，程序化眼睑眨眼 + 微扫视 |
| 爪子 | 无（整只猫一张） | `pawL / pawR` + `patchL / patchR` 局部精灵，按 zone 落键 |
| 尾巴 / 耳朵 | 焊在头或场景上 | 独立层，各带 `pivot`，小幅摆动 |
| 键帽 | 固定四个槽位 | 按 `row / column` 落在真实键位 |
| 接口 | `PetRasterFrame` 一组字段 | 追加 `blink / pawL / pawR / pawMouse / tailDeg / earDeg / breath`（全带默认值，v4 路径不变） |

## 2. 设计坐标系

- 设计画布 **720 × 960**（逻辑 pt），y 轴向下，原点左上。
- 素材统一 **2x** 出图（1440 × 1920），渲染器 `scaleBy(width / 720)` 后所有绘制都用 pt 坐标。
- manifest 里的 box / pivot / center / keyboardBox 都是 **2x 像素空间**，用 `point()` 或 `/ scale` 转成 pt。

## 3. 图层清单（18 张 PNG + manifest）

| 图层 | 文件 | 画布 | 说明 |
|------|------|------|------|
| 软阴影 | `shadow.png` | 全幅 | 键盘下接触阴影 + 猫身前缘淡阴影，透明底 |
| 键盘 | `keyboard.png` | 全幅 | 白色键盘（含两颗橙色键），连通域法抠出，底边去褐屑 |
| 鼠标 | `mouse.png` | 全幅 | 白色鼠标 |
| 身体 | `body.png` | 全幅 | 猫身（已扣掉 head_core，保留爪与尾的原始像素） |
| 颈补片 | `neck.png` | 全幅 | y 760–1210 / x 170–1100 的真实猫身像素，四边 90 渐隐；头部单独旋转时补缝 |
| 尾巴 | `tail.png` | 全幅 | 独立层，`pivot (905,1215)`，`swingDeg 2` |
| 头 | `head.png` | 全幅 | 头部（含颈部软裙边、挖掉耳朵、强制保留整颗眼球），硬 alpha + 0.8px 羽化 |
| 左/右耳 | `earL.png` / `earR.png` | 全幅 | `pivot (400,545)` / `(915,545)`，外扩 10px 与头部重叠 |
| 爪子 | `pawL.png` / `pawR.png` | 全幅 | 局部精灵，`progress > 0.01` 才画 |
| 爪补洞 | `patchL.png` / `patchR.png` | 全幅 | 盖住原爪位置 |
| 尾补洞 | `patchTail.png` | 全幅 | 保留资产，v5 不再绘制（尾层直接叠身体） |
| 虹膜 | `irisL.png` / `irisR.png` | 全幅 | 黄绿虹膜，配色从母版取样 |
| 瞳孔 | `pupilL.png` / `pupilR.png` | 全幅 | 纯黑瞳孔，按共视向量偏移 |
| 键帽 | `keycap.png` | 全幅 | 白键帽底 + 顶面，字母用 `Canvas` 文字叠加 |

## 4. 绘制顺序（`PetV5Renderer.draw`）

```
shadow → keyboard → mouse(含 pawMouse 下压) → body(呼吸) → neck
       → tail(绕 pivot 摆动) → pawL/pawR(含 patch) → keycaps
       → head(绕 neck 旋转, 内含耳与双眼)
```

键鼠在猫**之下**：爪子与尾巴天然盖住键鼠，键盘层不再需要对猫身挖洞。

## 5. 关键坐标（2x 像素）

| 名称 | 值 | 说明 |
|------|----|------|
| designSize / scale | 720 × 960 / 2 | 逻辑画布与素材倍率 |
| head.pivot（颈部） | (450, 962) | 头部旋转/俯仰支点 |
| tail.pivot | (905, 1215) | 尾巴摆动支点 |
| earL / earR pivot | (400, 545) / (915, 545) | 耳根 |
| pawL box | [246, 1282, 486, 1452] | 左爪 bbox |
| pawR box | [676, 1296, 916, 1452] | 右爪 bbox |
| keyboardBox | [70, 1400, 1010, 1600] | 键盘区域 |
| eyes.left | box (340,640) size 245×265，center (470.7,815.8)，radius 52.2 | 左眼 |
| eyes.right | box (585,630) size 260×270，center (735.6,796.6)，radius 57.9 | 右眼 |
| pupilRange | [26, 16] | 瞳孔位移上限（2x 像素） |
| keycaps | riseY 44 / life 0.6s / slots 4 | 键帽参数 |
| headRotate | yaw 6.0° / pitch 3.2° | 头部上限 |

## 6. 生成规则（复跑要点）

1. **头部剪影**：母版头部多边形向下延伸，再叠 940→1090 的渐隐软裙边（skirt），`head_m = max(head_m, skirt ∩ cat)`；`body = cat − head_core`（head_core 不含 skirt），避免同处半透明导致横向接缝。
2. **耳朵不重影**：head 里先扣掉 `feather(ear_core)`，耳层用 `MaxFilter(11)` 外扩 10px 与头重叠，旋转 ±5° 不露洞、不双耳。
3. **眼睛**：眼框内 `lum > 90` 的亮像素 → 最大连通块 → `binary_fill_holes(dilate 3)` 得整颗眼球；瞳孔 `lum < 74 ∩ ball` 取最大块；虹膜 = `ball − 瞳孔`，瞳孔区用八方向径向取样补虹膜色；`EB` 汇总两眼球后 `head_m = max(head_m, EB)`，彻底消除透底白眼眶。
4. **键盘**：白/橙做种子（`lum>100 & sat<0.26` 或 `R−G>62 & G−B>20`）→ `MaxFilter(11)/MinFilter(9)` → 最大连通块 → `binary_closing(15)` → `binary_fill_holes`，不再依赖多边形；再用键帽核心外扩 17px 收掉桌沿褐色飞边，底边 1558 以下剔除暖褐像素。
5. **木桌剔除**：全局 `lum>140 & (R−B)>34` 剔一次；body/tail 再收紧 `(R−B)<34`。
6. **颈补片**：`neck = cat ∩ box(760..1210, 170..1100)`，四边 90px 渐隐，画在 body 之上、head 之下。
7. **头部硬 alpha**：`head_a = (head_m > 0.45)` 再 `GaussianBlur(0.8)`，避免半透明裙边与身体二次合成出白边光晕。

## 7. 运行时参数（代码侧）

| 项 | 值 | 位置 |
|----|----|------|
| 头部偏航 | `gazeX * 6.0° + 微扫视 ±0.08°` | `PetStateMachine` v5 tick |
| 头部俯仰 | `(gazeY − 0.35) * 3.2° + ±0.05°` | 同上 |
| 眨眼 | 每 4.2s 一次，110ms 正弦 | `v5Blink` |
| 尾巴 | `sin(t*1.76) * 1.8°` | 同上 |
| 耳抽动 | `sin(t*2.9) > 0.96` 时 5° | 同上 |
| 呼吸 | `(sin(t/4.2*2π)+1)/2`，body scaleY `1+0.008·breath` | `PetV5Renderer` |
| 爪下压 | 左/右半屏 zone 触发弹簧，位移 3px + squash | `rasterPaw*` |
| 鼠标姿态 | 左右键按下 → `pawMouse` 弹簧，鼠标层下移 2× | `PetRuntime.handleRawEvent` |
| 键帽 | `centerX = kb[0] + kbW*(0.06 + col/13*0.86)`，`baseY = kb[1]+26+row/3*34`，帽 33×27pt，字号 11 | `drawKeycaps` |

## 8. 回滚

- 删除 `Resources/v5`（或 rename）即整体回退 v4 路径，`PetRasterRenderer.draw` 的 v4 分支保持原样。
- v4 资源目录保留一个发布周期；矢量皮肤仍是最终兜底。
