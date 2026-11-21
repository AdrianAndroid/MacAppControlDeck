# 技术设计：桌面宠物 v5 Living Rig

## 1. 总体方案

```text
NSEvent.mouseLocation (宠物所在屏 visibleFrame 归一化)
        │
        ▼
  GazeVector(x,y,z)  ── head yaw/pitch 修正 ──► 每眼球面投影 ──► EyeState(pupil, lid, highlight)
        │
   keyDown(keyCode) ──┬─► 键位坐标（PetKeyMap → 键盘投影） ──► 视线目标 / 键帽槽位
                     └─► 左右半区 ──► PawState(pawL/pawR translate/rotate/squash)
  mouseDown ──► PawState.right = .mouse + mouse.pressY

        ▼
PetRasterRenderer.draw(layers)  z 序：shadow → keyboard → mouse → body → tail → head(+eyes+lids) → paws → keycaps
```

与 v4 的差别：v4 是「scene + head + eyes + keycap」四段；v5 拆成 8 段并引入三个状态对象（Gaze / Eye / Paw）。
所有坐标仍走 manifest，Swift 里不写死。

## 2. 图层与 z 序（Resources/v5）

| z | 层 | 文件 | 关键字段 |
|---|----|------|----------|
| 0 | shadow | `shadow.png` | origin；仅静态，可预合成 |
| 1 | keyboard | `keyboard.png` | origin、`pressY` 18、`keyArea` 矩形（键位映射用） |
| 1 | mouse | `mouse.png` | origin、`pressY` 4 |
| 2 | body | `body.png` | origin；下缘 24px feather 已烘进 alpha |
| 2 | tail | `tail.png` | origin、`pivot`、`swingDeg` 4 |
| 3 | head | `head.png` | origin、`neck`、眼窝框、`earL`/`earR` 子框 |
| 3 | lidL / lidR | `lidL.png` / `lidR.png` | 与眼窝同框，闭合完整覆盖眼球 |
| 4 | pawL / pawR | `pawL.png` / `pawR.png` | `restBox` / `downBox` / `mouseBox`，`squash` |
| 5 | keycap | `keycap.png` | `slots`（键位上方）、`riseY` 90、`life` 0.6 |

补洞：`patchL/patchR` 与 `paw` 同框，绘制顺序 `body → patch → paw`，`patch` alpha 用 30px feather 与周围融合。

## 3. 视线与双眼

### 3.1 数据

```swift
struct GazeVector { var x, y, z: Double }          // 归一化；z>0 表示朝屏幕外（远）
struct EyeGeometry { var center: CGPoint; var radius: CGFloat }
struct EyeState {
    var pupilOffset: CGPoint   // 设计坐标（2x 前）
    var lidClose: CGFloat      // 0 开眼…1 闭合
    var highlightOffset: CGPoint
}
```

### 3.2 投影

```
d   = normalize(gaze)
d'  = R(-yaw, -pitch) · d                       // 抵消头部转动
R   = geometry.radius * 0.42                    // 眼球可转半径
k   = 1 + 0.35 * max(0, -d'.z)                  // 越近（z 越小）偏移越小 = 汇聚
off = CGPoint(R * d'.x / k, R * d'.y / k)
off = clampToEllipse(off, R * 0.9, R * 0.62)     // 眼眶椭圆软限
```

两眼使用同一个 `gaze` 与各自的 `geometry`，因此位移量不同但方向一致 —— 视觉上是"共同注视"，不是"各转各的"。

验收态：`angleBetween(eyeL.dir, eyeR.dir) < 1.5°`（`--debug-gaze` 下可视化）。

### 3.3 眨眼

- `lidClose(t)`：`t<40ms` 用 `smoothstep` 闭合，`40–60ms` 保持 1.0，`60–110ms` 打开。
- 触发：随机 3–7s；`typingBurst` 时权重 ×1.6；`sleeping` 时固定 0.65。
- 双眼共用同一个 `lidClose`，不允许各自相位。

### 3.4 微扫视

- 每 1.2–3.5s 生成 `saccade = (±0.08, ±0.06)` 叠加到 `gaze`，弹簧 900/30，180ms 内衰减回光标目标。
- 扫视期间头部不动（只动眼），避免"整只猫在抖"。

### 3.5 头部

| 参数 | v5 |
|------|----|
| yaw | ±6°（`headRotate.yawLimit`） |
| pitch | ±3.2° |
| 弹簧 | 190 / 28 |
| 滞后 | 40ms（先用眼，头再跟上） |

安全阀：yaw 超过 5° 且 `head/body` 重叠 < 14px 时自动降到 ±4°。

## 4. 爪子姿态

### 4.1 状态

```swift
enum PawPose { case rest, down, mouse }
struct PawState { var pose: PawPose; var progress: Double; var squash: Double }
```

### 4.2 目标变换

| pose | translate | rotate | squash |
|------|-----------|--------|--------|
| rest | (0,0) | 0 | 1.0 |
| down | (0, +4) | −2° | 0.94 |
| mouse | (mouseBox − restBox) | +6° | 0.97 |

`progress` 用 ease-out 120ms（down）/ 160ms（mouse），回弹 160ms；`squash` 用 `1 - 0.06·sin(π·progress)` 模拟压感。

### 4.3 键位映射

- `PetKeyMap` 提供 `keyCode → 键位行列`；manifest `keyboard.keyArea` 提供 4 行 × 列数矩形，插值得到键位中心（2x）。
- 左半区 → `pawL.down`，右半区 → `pawR.down`；同时按则两者都 down，`body.sink` 只计一次。
- 键帽槽位 = 键位中心 + 向上 18px；超出 4 个时按最近距离挑选，淘汰最旧。

### 4.4 鼠标

- 鼠标左/右键按下：`pawR.pose = .mouse`，`mouse` 层 `+pressY`，头偏 1.5°，不生成键帽。

## 5. 生命感

| 元素 | 驱动 | 幅度 / 周期 |
|------|------|-------------|
| 尾巴 | 绕 `pivot` 正弦 + 偶发甩尾 | ±4° @0.28Hz；±9° / 180ms（6–12s） |
| 耳朵 | 独立层 rotate | 6° / 60ms，8–20s 一次；打字 ×1.4 |
| 呼吸 | body scaleY 绕键盘上沿 | 1.0→1.008，4.2s；head 跟随 0.6 倍且相位偏 0.9s |
| 视线恢复 | 松键后 | 500ms 回光标 |

## 6. 时钟与性能

- 活动期 30fps、0.9s 无输入降 2fps（沿用 v4）。
- 静态层预合成：`shadow + keyboard + mouse(rest)` 首次渲染合成成一张 `NSImage` 缓存，每帧只画动态层（body / tail / head / paws / caps）⇒ 活动期实际合成 5 层。
- 素材常驻内存，帧内不新建 `NSImage`。
- 目标：活动 CPU < 8%、静止 < 3%、内存 < 90MB。

## 7. 回退与开关

- `PetRasterAssets` 探测顺序：`v5` → `v4` → 矢量；`v5` 缺任一必需层即整体回退 `v4`（不混搭）。
- 删除 `Resources/v5` 目录即回滚，用户设置不丢。
- `--debug-gaze` 只影响调试构建，不进入正式包。

## 8. 测试点

1. 共视夹角 < 1.5°（光标四角 + 中心 + 贴脸）。
2. 瞳孔子弹 clamp 在椭圆内，极端 `gaze` 不越界。
3. 眨眼：双眼 `lidClose` 相等；110ms 内完成；睡眠 0.65。
4. 扫视注入后 180ms 内回到光标目标（容差 0.02）。
5. 补洞渲染：`patch` 只在 `paw` 框内绘制，不污染键盘层。
6. 两爪同时按：两者 `pose == .down`，`body.sink` 计数为 1。
7. 鼠标按下：`pawR == .mouse`、`keycapCount == 0`。
8. 键帽槽位：`M` 键生成的槽位位于该键位上方 ±2px；超 4 个淘汰最旧。
9. 资产缺失：缺 `lidR.png` 时整体回退 v4，不出现半套图层。
10. 几何：三档尺寸下所有层框仍在窗口内，命中区与 v5 版面一致。
