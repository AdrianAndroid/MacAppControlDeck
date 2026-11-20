# capture-overlay-parity 规格

## ADDED Requirements

### Requirement: 工具条围绕选区布局

区域截图进入编辑态后，系统 SHALL 在选区周边显示工具条：横向工具条位于选区下方居中，竖向动作栏位于选区右侧并与选区顶部对齐；空间不足时按固定优先级换边。

#### Scenario: 常规选区

- **WHEN** 用户拖出选区且选区下方有足够空间
- **THEN** 横向工具条出现在选区下方 6pt 处并水平居中
- **AND** 线宽/线型选项行出现在工具条下方 2pt 处
- **AND** 竖向动作栏出现在选区右侧 6pt 处，顶边与选区顶边对齐

#### Scenario: 靠近屏幕边缘

- **WHEN** 选区右侧空间不足
- **THEN** 竖向动作栏移到选区左侧
- **AND** 两侧都不足时移到选区下方，仍保持在屏幕内

#### Scenario: 拖动选区

- **WHEN** 用户拖动或缩放已创建的选区
- **THEN** 工具条随选区移动重新定位，不重建按钮、不闪烁

### Requirement: Retina 像素语义

选区尺寸、分辨率预设与导出结果 SHALL 以物理像素为单位，与屏幕缩放无关。

#### Scenario: 2x 屏幕拖选

- **WHEN** 用户在 2x 屏幕上拖出 600×360 pt 选区
- **THEN** 尺寸框显示 `1200 × 720`
- **AND** 保存的图片为 1200×720 像素

#### Scenario: 输入精确尺寸

- **WHEN** 用户在 W×H 输入框输入 1080×1080 并回车
- **THEN** 选区调整为 1080×1080 物理像素

### Requirement: 即时响应

打开选区 SHALL 立即显示遮罩，冻结帧允许异步就绪；抓帧不得把覆盖层自身截入。

#### Scenario: 快速连续截图

- **WHEN** 用户按热键打开区域截图
- **THEN** 遮罩立即出现，不等待整屏抓图完成
- **AND** 冻结帧就绪后用于吸附与导出，且不包含遮罩或工具条

### Requirement: 权限与热键可用性

系统 SHALL NOT 因 `CGPreflightScreenCaptureAccess()` 的误报阻断截图；热键注册失败后 SHALL 自动重试。

#### Scenario: 已授权但预检误报

- **WHEN** 系统设置中已勾选屏幕录制，但预检返回 false
- **THEN** 应用仍尝试抓图
- **AND** 抓图成功时不显示授权提示

#### Scenario: 热键被其他应用占用

- **WHEN** 启动时 `RegisterEventHotKey` 返回错误
- **THEN** 每 2 秒重试，直至注册成功

### Requirement: 钉图 Esc 关闭

钉住的图片 SHALL 支持无需点击、鼠标悬停其上即可按 Esc 关闭。

#### Scenario: 悬停关闭

- **WHEN** 鼠标位于某张钉图上并按下 Esc
- **THEN** 该钉图关闭，其他钉图不受影响
- **AND** 鼠标不在任何钉图上时，Esc 不被应用拦截
