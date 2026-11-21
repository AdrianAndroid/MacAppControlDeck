# 桌面宠物 v5「Living Rig」归档摘要

- change-id：`add-desktop-pet-v5-living-rig`
- 日期：2026-11-21
- 计划：`Docs/plans/2026-11-21-desktop-pet-v5-living-rig.md`
- 分层规格：`Docs/design/desktop-pet-v5-layer-spec.md`
- 资产脚本：`Docs/design/pet-v5-build-assets.py`（仓库根目录执行，源图 `Docs/design/clean-desktop-pet-v4-desk-keyframe.png`）

## 为什么做

v4 交付后用户针对 v4 动效板提了三条批评：

1. **「眼睛是分开动的，一点也不生动」**：v4 的 `eyeL`/`eyeR` 是两张独立 PNG，按同一向量各平移一次，素材本身不对称、没有共视点、没有眼睑。
2. **「桌面不要了，只保留键盘鼠标小猫，桌面像被截断太突兀」**：v4 的 `scene` 层带整张木桌，alpha 是按「桌在底下」抠的，一旦想换背景就露馅。
3. **「落爪姿态切换都没做」**：三张关键帧不对齐（2x 下垂直错位 106px、桌面线差 35px、`mouse` 帧只有右眼），整场景交叉淡化必然双影。

v5 的目标是把它做成**活骨架（Living Rig）**：单场景分层 + 局部器官运动，不再靠整帧切换。

## 做了什么

### 1. 去桌面（场景重构）

- 从母版重新拆出 `shadow / keyboard / mouse / body / neck / tail / head / earL / earR / pawL / pawR / patchL / patchR / patchTail / irisL / irisR / pupilL / pupilR / keycap` 共 18 张 PNG + `manifest.json`。
- 木桌像素全部置透明，只剩猫、键鼠与一层柔和接触阴影；键盘含两颗橙色键，无空洞。
- 绘制顺序改为「键盘 → 鼠标 → 身体 → 颈补片 → 尾巴 → 爪 → 键帽 → 头」，键鼠在猫**之下**，爪子与尾巴天然盖住键鼠，键盘层不再需要对猫身挖洞。

### 2. 双眼共视 + 眼睑

- 眼球切分改为「眼框内亮像素 → 最大连通块 → fill_holes(dilate 3)」，瞳孔取最暗块，虹膜 = 眼球 − 瞳孔，瞳孔区用八方向径向取样补虹膜色；`head_m = max(head_m, EB)` 强制保留整颗眼球，彻底消除「透底白眼眶」。
- 渲染侧：虹膜像素固定，只有瞳孔按 `frame.eyeX/eyeY` 偏移（上限 ≈ 眼半径 45%），两眼共用同一向量，视线夹角恒定。
- 眼睑在 `drawEye` 里程序化绘制（椭圆 clip + 毛色填充 + 下缘一道淡光），每 4.2s 一次、110ms 正弦；叠加 ±0.08 / ±0.05 的微扫视。

### 3. 落爪与按鼠标姿态

- `pawL / pawR` 局部精灵 + `patchL / patchR` 补洞，光标在左/右半屏时对应爪以弹簧落下（位移 3px + squash），不做整帧切换。
- `PetInputMonitor` 新增 `.mouseDown/.mouseUp`（mask 里补 `.leftMouseDown/.leftMouseUp/.rightMouseDown/.rightMouseUp`），`PetRuntime` 收到按下后给状态机 0.35s 窗口，驱动 `pawMouse` 弹簧，鼠标层随之下沉 2×。

### 4. 生命感与键帽因果

- 尾巴独立层绕 `pivot (905,1215)` 慢摆 `sin(t*1.76)*1.8°`；耳朵 `sin(t*2.9) > 0.96` 时抽 5°；身体 4.2s 一次呼吸（`scaleY 1+0.008·breath`），头部按 0.6 倍跟随。
- 键帽从**真实键位**升起：`PetKeycap` 增加 `row/column`，`drawKeycaps` 用 `centerX = kb[0] + kbW*(0.06 + col/13*0.86)`、`baseY = kb[1] + 26 + row/3*34` 定位，帽 33×27pt、字号 11。

### 5. 头身缝隙

- 头单独 ±6° 旋转会露出「头底边 ↔ 身体顶边」的缝隙（白底）。新增 `neck` 补片：取 y 760–1210 / x 170–1100 的真实猫身像素、四边 90px 渐隐，画在 body 之上、head 之下；头部硬 alpha（`> 0.45` 再 0.8px 羽化），避免半透明裙边与身体二次合成出白边。

## 关键决策与踩坑

- **不做三帧整场景交叉淡化**（v4 已验证做不通）；**爪子走「局部精灵 + 补洞」**；**眼睛走完整 3D 视线方案**（共视 + 眼球约束）；**软阴影收口**代替桌面——四条默认决策用户全部接受。
- 头/身接缝：初版 `head_poly` 底边在 y≈890–930 横切穿过口鼻，`body = cat − head` 后两层同处半透明 → 露背景成横线。改为「头部多边形向下延伸 + 940→1090 渐隐裙边」且 `body` 只用 `head_core_m` 扣头。
- 耳重影：head 里含耳朵再画耳层会双耳。改为 `head_m -= feather(ear_core)`，耳层 `MaxFilter(11)` 外扩 10px 重叠。
- 键盘黑洞：多边形 + 暖色过滤把两颗橙键挖成黑洞。改为「白/橙做种子 + MaxFilter/MinFilter + 最大连通块 + closing + fill_holes」的连通域法。
- 白眼球：早期 `head` 的眼球区 alpha=0（亮眼像素被 `(178−lum)/58` 判成背景）。修法见上（眼球整块保留）。
- 键帽不显示（最坑）：`keyboardBox` 是 2x 设计像素，`drawKeycaps` 却直接当 pt 用，键帽被画到 960pt 画布之外——测试里表现为「带键帽帧与 idle 帧 tiff 字节完全相同」。改成 `kb / m.scale` 后正常。
- 测试环境资源加载：`PetV5Assets.locate()` 只搜 `Bundle.main`，在 xctest 进程里 main 是 runner，导致 `PetV5Assets.shared == nil`，渲染测试全部退回 v4。改为优先 `Bundle.module.resourceURL/v5`。

## 验证

- `swift test`：**103 项 0 失败**（新增 `PetV5RigTests` 13 项：manifest 解码、颈部 pivot、双眼同半径量级、keyboardBox、18 个资产文件、idle 中性 extra、眨眼整帧标量、左右区爪下压、头转 ≤6.5°、键帽携带真实 row/column、v5 渲染路径可用、双眼瞳孔同向位移、键帽从键盘区升起；其中后两项用 `ImageRenderer` 实渲染后做像素级断言）。
- `./Build/build.sh` release + 自签名（`MacAppControlDeck Self-Signed`）通过，覆盖安装 `/Applications/MacAppControlDeck.app`。
- 实机（3440×1440 @2x）：`cliclick m:` 把光标打到左下 / 右上，两帧截图对比——**两只眼瞳孔同向偏移、头部同时偏转**；`CGEventPost` 连按字母，截图抓到 `D / R / H / S / C / B` 键帽从对应键位升起；转头帧不再露白缝。
- 性能：idle + 30fps 悬停时 `%CPU ≈ 6.9`（含截图/录屏等常驻模块）。

## 边界与回滚

- 有 v5 素材时桌宠固定为黑猫，五套皮肤 / 键盘主题入口收起；素材缺失整条链路回退 v4，再回退矢量皮肤。
- 删除 `Resources/v5` 即可整体回退 v4，不丢用户设置，编译不受影响；`Resources/v4` 保留一个发布周期。
- R0：沿用已有内置入口 `pet.open`（`BuiltinActions.swift` → `PetModule.shared.open()`），**未新增打开按钮**，属「已有打开按钮的功能内部新增子能力」。

## 遗留

- 键盘底边与尾根仍有极小褐色残屑（键盘层底边已做剔除，尾根几像素未清），在 288pt 窗口下基本不可见。
- `patchTail` 资产保留但 v5 不再绘制（尾层直接叠身体）。
- 眼睛共视的回归测试用「两帧眼框内差异像素数 + 位移方向一致」近似，未做逐像素瞳孔质心（多种配色下不稳）。
