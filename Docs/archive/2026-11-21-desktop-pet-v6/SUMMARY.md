# 桌面宠物 v6「Full-Body Rig」归档摘要

- change-id：`add-desktop-pet-v6-full-body-rig`
- 日期：2026-11-21
- 计划：`Docs/plans/2026-11-21-desktop-pet-v6-full-body-rig.md`
- 分层与骨骼规格：`Docs/design/desktop-pet-v6-layer-spec.md`
- 资产脚本：`Docs/design/pet-v6-build-assets.py`（仓库根目录执行，源图 `Docs/design/v6-{cat,keyboard,mouse}-master.png`）
- 代码：`Modules/Pet/PetRasterV6.swift`（新增）、`PetRasterRig.swift`、`PetStateMachine.swift`、`Package.swift`
- 测试：`Tests/.../PetV6RigTests.swift`（8 项），全量 111 项 0 失败

## 为什么做（v5 被实机否决）

v5「Living Rig」上线当天被用户逐条否决，原话归纳为「键盘抠图残边、鼠标不精细、眼睛跟随几乎看不出、按键只有脚趾级小动画、尾巴不动、身子与胳膊呆板、键帽弹起距离太短」，并明确要求「不怕改动大，一定要整体协调、活灵活现，真正是在动的一只小动物；动作可以少一点但必须生龙活虎」。

量化归因（三条根因）：

1. **振幅口径错**：v5 所有位移都在 720×960 设计坐标里取值，屏上按 0.4 倍缩放后全部低于 3pt 可见阈值——「在动」在数学上成立，在眼睛里不成立。
2. **分层里没有关节**：只有 `body` 一整块、`pawL/pawR` 两片爪，没有上臂 / 前臂 / 颈 / 肩 / 头身分离，所以按键时唯一能动的就是爪精灵平移 3px，身子与胳膊必然呆板。
3. **素材来源脏**：键盘靠「颜色种子 + 连通域 + 闭运算」从带桌子的合成图里抠，底边被硬切成褐色碎屑；鼠标用低对比白∩区域 + 1.5px blur，滚轮缝被磨平。

## 做了什么

### 1. P0：三张独立干净母版（放弃「从合成图抠」）

| 母版 | 做法 | 结果 |
| --- | --- | --- |
| 键盘 | `image_gen` + `transparent:true` 独立出图，提示词写死「空白键帽、两端各一颗橙键、矮轴、不裁底边」 | 2379×991，真透明 40% |
| 鼠标 | 同上，写死「极简扁平纯白无线鼠标、滚轮缝清晰」 | 1773×1330，真透明 69% |
| 猫 | `image_edit` 以 v4 母版为参考，要求「姿态 / 毛色 / 爪位不变，只去掉桌椅键鼠，纯白底」 | 1373×1717，姿态与参考一致 |

抠猫链路：近白掩膜 → 贴边连通域 → **先 pad 再** closing/dilate（否则边界处理会把整图背景误判成洞）→ fill_holes → 最大连通域 → blur 0.9 → **unpremultiply 去白晕**（`(rgb-255*(1-a))/a`）→ `alpha**1.12`，并把 `y>950 且 lum>110` 的反光残留直接清零。

### 2. P1：17 层解剖分层

`shadow / keyboard / keycap / tail1 / tail2 / mouse / torso / armL / armR / neck / head / earL / earR / iris_l / pupil_l / iris_r / pupil_r` + `manifest.json`（designSize / scale / canvas / order / rig / keyboardGrid）。

两条关键经验：

- **接缝不能用软边 feather**。第一版用 feather 10 切层，相邻层在接缝各 0.5 alpha，合成后 0.75，一条白线横穿整只猫。改为 `grown()`：hard polygon 先 `binary_dilation(12)` 再 `blur(3)`，让前层外扩压住后层。
- **`torso` 不能用「补毛填充」**。多边形扩散填充出来的毛色与真实毛色不同，会划出横平竖直的浅色块。最终定为：`torso` 保留整只猫的真实像素，只把眼窝 socket 补成毛色；这样任何层转动都不露白、也不出现旧眼睛。

### 3. P2：统一躯干坐标系（解决「整体不协调」）

所有部件挂在同一个躯干坐标系下：

```text
torso(绕 hip)
 ├ tail1(绕 tailRoot) └ tail2(绕 tailMid，叠在段1 内)
 ├ armL / armR（绕 shoulder，+push +slide）
 └ neck
    ├ head（绕 neck，yaw/pitch）
    │  ├ earL / earR（绕耳根）
    │  └ iris → pupil（眼窝内受限偏移）
```

躯干一动，头、耳、双臂、两段尾巴全部跟随——这是结构性解法，不是靠调参凑出来的协调。`PetV6RigTests.testTorsoTiltDragsHeadArmsAndTail` 把这条不变量写成了断言。

两个踩过的坑写进了代码注释：`manifest` 里 `box` 是 asset px 而 `pivot` 是裁切后 local px、`rig` 是 design pt，混用会让头绕错误的圆心摆动并撕出大洞；`NSImage.size` 对无 DPI 的 PNG 等于像素数，不除以 `scale` 会把整图放大 2 倍。

### 4. P3：运动语法（按屏上可感知定标）

| 输入 | 全身响应 |
| --- | --- |
| 光标 | 虹膜 ±11.6/7.4 + 瞳孔 ±13.7/8.4 + 头 yaw ±8°/pitch ±4° + 躯干倾 `(gazeX-0.2)*3.4` |
| 按键 | 该侧臂绕肩旋转 + 下压 26pt + **跟列** `clamp(keyX-pawHome, ±32)`、键帽弹起 85pt、躯干前倾、颈低头、耳压、尾巴加速度 |
| 鼠标按下 | 右臂压到鼠标上方、鼠标下沉 2pt + 轻微压扁、躯干右倾 |
| 静止 | 呼吸升降、尾段1 `sin(t*1.36)*5.2`、段2 相位 0.18s 摆 ±7.4、耳抽动、4.2s 眨眼 |

`reduceMotion` 打开时全部振幅归零，只保留键帽与状态切换。

### 5. P4：键帽

从 `keyboardGrid`（`colStartX 133 / colGap 33.4 / backRowY 792 / rowGap 38`）算键位，升起 85 设计 pt（屏上约 34pt），生命 0.8s 三段曲线（0.18 快弹 → 0.62 悬停 → 回落淡出），帽面印真实字符，带光带投影与 ±2.5° 歪斜。键帽画在键盘之后、猫之前，猫爪自然压在键帽前。

## 偏离记录

原计划的「两段解析 IK」没有落地：母版里前臂是一整块连续毛皮，硬切两段再相对旋转会出现「断臂」断层，比 v5 更差。改采「单骨前臂 + 肩轴旋转 + 有界跟列」，并在 spec delta 里把契约改写为实际方案。详见 `design.md` 第 8 节。

## 验收

- `swift test`：111 项 0 失败（新增 `PetV6RigTests` 8 项）
- release 构建 + 自签名 + 覆盖安装 `/Applications`，实机窗口 374×499 截图确认：瞳/头/躯干随光标明显联动、打字时键帽明显弹起、前臂向键列靠拢
- README 主视觉与两张对照图（gaze / keycaps）全部换成 v6 实机截图
- R0：沿用既有 `pet.open` 内置入口（`BuiltinActions` → `PetModule.shared.open()`），v6 无新增用户可见入口

## 回滚

删除 `Sources/MacAppControlDeck/Modules/Pet/Resources/v6` 即按 v6 → v5 → v4 → 矢量逐级回退，设置不丢。v5 资源保留一个发布周期。
