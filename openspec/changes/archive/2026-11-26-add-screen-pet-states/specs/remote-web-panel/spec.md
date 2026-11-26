# remote-web-panel Delta

## ADDED Requirements

### Requirement: 副屏宠物状态化

副屏宠物 SHALL 按真实数据在 `idle / sleep / rain / cold / hot / packup / celebrate` 之间切换，优先级为 `celebrate > packup > sleep > rain > cold > hot > idle`。

#### Scenario: 睡觉

- **WHEN** Mac 墙钟在 00:00–06:00，或周末 22:00 之后
- **THEN** 宠物原地不动、身体压扁，头顶飘 Zzz，文案显示「睡了」

#### Scenario: 天气反应

- **WHEN** 今天降水概率 ≥ 60%
- **THEN** 宠物撑伞并有雨滴下落，文案显示「打伞」
- **WHEN** 当前温度 ≤ 5° 或 ≥ 30°
- **THEN** 分别显示围巾发抖 / 汗滴

#### Scenario: 下班

- **WHEN** 工作日且下班倒计时剩余 ≤ 30 分钟
- **THEN** 宠物原地看表，文案显示「还有 N 分钟下班」
- **WHEN** 工作日且倒计时进入 off 阶段
- **THEN** 宠物原地弹跳并闪星，文案显示「已下班」

#### Scenario: 关闭环境反应

- **WHEN** 设置里关闭「宠物随环境变化」或天气/倒计时不可用
- **THEN** 宠物回到 idle，不显示错误与占位文案

### Requirement: 副屏性能基线

副屏长期常亮时 SHALL 只保留一个 rAF 主循环，宠物 30fps、时钟每秒最多重绘一次，且宠物动画不得每帧读取 DOM 或重建 SVG。

#### Scenario: 零布局抖动

- **WHEN** 宠物移动 / 换状态
- **THEN** 只写 `transform` 与 `data-*` 属性，尺寸从缓存读取
- **AND** 页面隐藏时主循环与 CSS 动画都停止

#### Scenario: 低动效

- **WHEN** 系统开启「减弱动态效果」
- **THEN** 取消位移、抖动与弹跳，仅保留静态道具
