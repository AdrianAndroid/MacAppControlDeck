# pet-live2d-bongocat 规格

## Purpose

约束桌宠的 BongoCat standard 场景：使用官方鼠标＋完整键盘模型，背景、模型和键位图共享 612×354 画布投影，窗口按 612:372 留出键盘余量；桌面只来自背景，键位高亮置顶，并响应真实键盘与鼠标输入。

## Requirements

### Requirement: 官方 standard 场景

桌宠 SHALL 提供 BongoCat standard 的「鼠标＋完整键盘」场景：背景、键位图和 Live2D 模型均来自 standard 资源；模型使用官方 612×354 画布，不得用旧 keyboard 方向键场景替代。

#### Scenario: 默认打开

- **WHEN** 用户打开使用 `model=bongocat` 的桌宠
- **THEN** 画面呈现白猫、完整键盘和鼠标，背景与键位图满幅覆盖画布
- **AND** 不出现方向键专用布局或旧自产外观

### Requirement: 统一画布投影

背景、模型和键位图 SHALL 共享同一变换：`scale = min(w / 612, h / 354)`，画布在窗口内居中；模型 SHALL 保持 `position=(0,0)`、`anchor=0`、`scale=1`。窗口 SHALL 使用 612:372 比例，为背景键盘保留上下余量，键盘右侧与底行不得被窗口裁切。

#### Scenario: 大尺寸窗口

- **WHEN** 桌宠以 large 档位显示
- **THEN** 612×354 画布按比例缩放并居中，键盘最底一行完整可见
- **AND** 背景、猫头和双臂保持同一投影，不发生相对错位

### Requirement: 单一桌面来源

桌宠场景 SHALL 只由一张 `background.clean.png` 提供鼠标垫、键盘和桌面轮廓；背景 SHALL 是透明 PNG，不得保留官方白桌、桌线或独立投影。场景画布 SHALL 保持 612×354，由 `background.clean.png` 满幅覆盖。

#### Scenario: 无白桌悬浮

- **WHEN** 桌宠在任意壁纸上显示
- **THEN** 画面只有完整圆角鼠标垫、完整键盘和动态猫
- **AND** 不出现白色桌面、第二根桌线或键鼠被画布裁断的边

### Requirement: 键位高亮置顶

键位高亮图层 SHALL 绘制在背景和模型之上，真实输入引起的高亮不得被模型、桌面或背景遮挡。该图层沿用官方 612×354 键位坐标；当背景键盘被替换为不同透视的完整键盘时，允许高亮与键帽位置暂时不完全对齐，但该限制 SHALL 在发布说明中列为已知问题，直到逐键重映射完成。

#### Scenario: 按住 A

- **WHEN** 用户按下物理 A 键
- **THEN** 键位高亮显示在最上层，松开后正常回落
- **AND** 若高亮坐标尚未按新键盘重映射，发布说明必须披露该偏差

### Requirement: 真实输入语义

桌宠 SHALL 使用 macOS 物理键码映射 standard 资源名，支持组合键与多键同时高亮；鼠标左右键 SHALL 独立驱动对应参数和键位图。没有对应键位图的按键不得驱动爪子。

#### Scenario: 组合键

- **WHEN** 用户按住 Shift 后再按 A
- **THEN** Shift 与 A 同时高亮，爪子保持按下状态

#### Scenario: 鼠标右键

- **WHEN** 用户按住鼠标右键
- **THEN** 右键独立显示高亮，不与左键状态串用

### Requirement: 资源缓存隔离

承载 Live2D 的 WebView SHALL 使用非持久数据存储，启动时不得复用自定义 scheme 下的旧 `app.js` 缓存。

#### Scenario: 更新前端脚本后重启

- **WHEN** 应用更新 `app.js` 后重新启动桌宠
- **THEN** WebView 加载本次构建的脚本，不出现旧布局继续运行

### Requirement: 素材发布边界

BongoCat standard 模型与键位素材的来源和许可证 SHALL 在公开发布前核实并记录；确认上游为 Apache-2.0 后，方可进入公开发布包。发布包 SHALL 随附上游许可证原文与本项目修改说明。

#### Scenario: 准备公开发布

- **WHEN** 应用准备对外分发
- **THEN** `THIRD_PARTY_NOTICES.md` 记录上游地址、固定提交、许可证和改动范围
- **AND** 安装包内包含 `Licenses/BongoCat-LICENSE.txt`
