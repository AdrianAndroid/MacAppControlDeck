# 任务清单：add-desktop-pet-v5-living-rig

> 状态：**已交付**（2026-11-21）。全部勾选；与计划的偏差写在行尾括号里。

## 1. 场景重构：去桌面

- [x] 1.1 从母版重新拆 `shadow` / `keyboard` / `mouse` / `body` / `tail` / `head` 六层（不含木桌）
- [x] 1.2 木桌像素全部置透明；猫身与桌板交叠区用 `alpha ∩ bodyMask` 贴回母版猫身像素
- [x] 1.3 键盘层在猫身前遮挡（键鼠画在猫之下），`body` 不再做桌线 feather（无桌面可 fade）
- [x] 1.4 `shadow.png`：键盘下接触阴影 + 猫身前缘淡阴影（椭圆高斯，透明底，可预合成）
- [x] 1.5 `tail` 独立层（`pivot (905,1215)`），`patchTail` 资产保留但不再绘制
- [x] 1.6 写 `manifest.json` v5：layers / eyes / keycaps / keyboardBox / headRotate
- [x] 1.7 资产校验：缺任一层整体回退 v4，不混搭半套
- [x] 1.8 静态合成目检：无桌线、无木纹、无矩形底、无灰晕、猫身下缘无硬边

## 2. 眼部系统

- [x] 2.1 新增 `GazeVector` / `EyeGeometry` / `EyeState`，`PetStateMachine` 接共视投影
- [x] 2.2 头部 yaw ±6°/pitch ±3.2°、弹簧 190/28、40ms 视觉滞后 + 露底自动降压
- [x] 2.3 眼睑改为程序化绘制（椭圆 clip + 毛色填充 + 下缘淡光），每 4.2s 一次 110ms 正弦、双眼同相（不新增 lid PNG）
- [x] 2.4 微扫视（1.2–3.5s、±0.08、900/30、180ms 衰减）与高光反向微移（−0.32×）
- [x] 2.5 `--debug-gaze` 可视化：视线向量 + 两眼方向夹角

## 3. 爪子姿态

- [x] 3.1 切 `pawL` / `pawR` 精灵与 `patchL` / `patchR` 补洞（30px feather）
- [x] 3.2 `PawState`（rest/down/mouse、progress、squash）与绘制顺序 body → patch → paw
- [x] 3.3 键位映射：`PetKeyMap` 行列 → manifest `keyboard.keyArea` → 键位中心，左右半区分爪
- [x] 3.4 落键：爪下压 3px + squash（`scaleY 0.95`），不做键位独立下沉（键帽自身有升起-悬浮-淡出）
- [x] 3.5 鼠标：左右键按下进入 0.35s 窗口驱动 `pawMouse` 弹簧，`mouse` 层下沉 2×，不生成键帽

## 4. 生命感与键帽因果

- [x] 4.1 `tail` 绕尾根 `sin(t*1.76)*1.8°` 慢摆（幅度收敛到 1.8°，避免尾根硬边）
- [x] 4.2 `earL` / `earR` 独立层，`sin(t*2.9) > 0.96` 时反向抽 5°
- [x] 4.3 `body` 呼吸 `scaleY 1+0.008·breath` / 4.2s，head 同相位跟随
- [x] 4.4 键帽按 `row/column` 映射真实键位（`riseY 44` 2x 像素），起点即键位上方
- [x] 4.5 松键 500ms 后视线回光标；持续打字不抖动

## 5. 验证

- [x] 5.1 `swift test` 103 项全绿，其中新增 `PetV5RigTests` 13 项（共视夹角、瞳孔 clamp、眨眼相位、扫视、补洞越界、双爪同按、鼠标不生成键帽、槽位映射），既有 90 项全绿
- [x] 5.2 `./Build/build.sh` release + 自签名通过
- [x] 5.3 覆盖安装 `/Applications/MacAppControlDeck.app` 并实机启动
- [x] 5.4 实机截图：透明无桌待机、光标左右共视、眨眼中帧、双爪落键、右爪按鼠标、键帽从键位升起
- [x] 5.5 2× 目检键盘边、猫身下缘、补洞区与转头缝隙（新增 `neck` 补片后无白缝）
- [x] 5.6 性能实测：整机 idle+30fps 悬停 `%CPU ≈ 6.9`（含其他常驻模块），RSS ≈ 290MB（含截图/录屏模块，未单独拆分）

## 6. 文档与归档

- [x] 6.1 README 桌宠章节改 v5（去桌面、共视、眨眼、落爪、键帽键位）
- [x] 6.2 `Docs/design/desktop-pet-v5-layer-spec.md`
- [x] 6.3 `Docs/archive/2026-11-21-desktop-pet-v5/SUMMARY.md`
- [x] 6.4 `openspec/specs/desktop-pet/spec.md` 同步 v5 delta（含 REMOVED「单帧场景与头部/键帽反馈」）
- [x] 6.5 归档到 `openspec/changes/archive/2026-11-21-add-desktop-pet-v5-living-rig/`
- [x] 6.6 提交说明引用 `add-desktop-pet-v5-living-rig`；写明沿用 `pet.open`，无新增入口

## 7. 回滚

- [x] 7.1 删除 `Resources/v5` 回退 v4，用户设置不丢
- [x] 7.2 v4 资源目录保留一个发布周期
- [x] 7.3 矢量皮肤仍为最终兜底

## 8. 执行中新增（计划外）

- [x] 8.1 新增 `neck` 颈补片层：头单独 ±6° 旋转时补住「头底边 ↔ 身体顶边」的白缝
- [x] 8.2 头部改硬 alpha（`>0.45` + 0.8px 羽化），消除半透明裙边与身体二次合成的白边光晕
- [x] 8.3 键盘层底边剔除桌沿褐色残屑（键帽核心外扩 17px + 底边 1558 以下去暖褐）
- [x] 8.4 `PetV5Assets.locate()` 优先 `Bundle.module`，否则测试进程取不到 v5 资产
