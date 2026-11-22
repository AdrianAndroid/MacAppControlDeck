# adopt-bongocat-live2d-model

## Why
用户给出的真实参考是 BongoCat **standard** 的“鼠标＋键盘”场景。此前误接为 keyboard 的“方向键＋键盘”，且沿用旧桌宠动画角度、最近键字符和 200ms 超时的近似驱动，模型、键位命名和输入语义均与官方不一致。

## What Changes
- 新增 `Resources/live2d/bongocat-standard/`，使用 BongoCat 官方 standard 的模型、贴图、背景、53 个键位图、表情和动作；`model=bongocat` 默认指向 standard，keyboard 资源仅保留作兼容。
- 按官方 v2.4.1 源码对齐参数与运行顺序：motion 后写入 input 和 automatic effects，再由运行库执行 physics、pose 与 core update；接入归一化参数、五组呼吸正弦、5 秒眨眼周期及配件隐藏。
- 改为真实物理输入：standard 的右爪操作鼠标、左爪响应键盘；鼠标左右键独立；按下/松开状态支持组合键与多键 overlay；无对应键位图时不驱动爪子。
- 使用 macOS 物理键码映射官方资源名：`Num*`、`Meta`、`Fn` 等；数字小键盘复用主键区素材。
- 光标按屏幕归一化为左上 `(+1,+1)`、右下 `(-1,-1)`，并按每 60fps 帧 `0.75` 系数阻尼；跨屏时直接切换视口。
- 使用统一的 612×354 画布变换：模型保持 `(0,0)`、`anchor=0`，背景和键位图共享同一投影；窗口采用 612:372，给完整键盘保留上下余量。
- standard 场景关闭模型自带的 `table`、`table2` 网格，避免覆盖背景键盘并产生第二条桌线；键位高亮始终绘制在模型之上。
- 窗口和 SwiftUI 根视图改为 612:372 横版比例，默认基准宽度 350，避免竖窗大片透明空区。
- 自产 V4–V13 外观只保留历史文件，不再作为默认显示或设置页说明。

## Capabilities
- `pet-live2d-bongocat`：展示官方 standard 模型，并响应真实键盘、组合键、鼠标左右键与全屏光标。

## Impact
- `PetLive2DView`、live2d `app.js`、`PetInputMonitor`、`PetRuntime`、`PetGeometry`、`PetPanelController`、`PetSceneView`、`PetSettings` 与设置页。
- 实机验收：A 键、Shift+A、鼠标左/右键、光标四角及连续打字均已验证；修复后封面为 `Docs/design/desktop-pet-bongocat-standard.png`，演示素材已同步更新。
- 授权说明：BongoCat 代码为 Apache-2.0；模型素材源自 BongoCat/Bongo-Cat-Mver 社区，目前按用户确认仅作本机原型，未确认素材再分发授权前不进入公开发布包或 README 宣传图。

## 非目标
- 不重写为 Tauri/Rust；不引入手柄模式；不新增用户可见入口（沿用 `pet.open`）；不重新设计模型外观。
