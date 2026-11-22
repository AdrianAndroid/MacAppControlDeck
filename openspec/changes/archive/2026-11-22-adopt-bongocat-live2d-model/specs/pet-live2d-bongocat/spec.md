# pet-live2d-bongocat 规格 delta

## ADDED Requirements

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

standard 模型自带的 `table`、`table2` 桌面网格 SHALL 在每帧更新后被关闭；桌面、桌线、鼠标垫和键盘只由背景图提供。不得通过关闭整个 `Part` 隐藏桌面，以免同时移除右爪或鼠标。

#### Scenario: 桌线连续

- **WHEN** standard 场景完成首帧渲染
- **THEN** 画面只有一条来自背景的桌线
- **AND** 背景键盘不被模型桌面遮挡，右爪和鼠标仍然可见

### Requirement: 键位高亮置顶

键位高亮图层 SHALL 绘制在背景和模型之上，真实输入引起的高亮不得被模型、桌面或背景遮挡。

#### Scenario: 按住 A

- **WHEN** 用户按下物理 A 键
- **THEN** A 键位高亮显示在最上层，左爪落到对应键位
- **AND** 松开后高亮与爪子状态在下一帧正确回落

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

在模型和键位素材的再分发授权核实前，standard 资源 SHALL 仅用于本机原型，不得进入公开发布包或对外宣传素材。

#### Scenario: 准备公开发布

- **WHEN** 应用准备对外分发
- **THEN** 先确认素材授权或替换为可再分发资源
- **AND** 未确认前不打包、不宣传 standard 素材
