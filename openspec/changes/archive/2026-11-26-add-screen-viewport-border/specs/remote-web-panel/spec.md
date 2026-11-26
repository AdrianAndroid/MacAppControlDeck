# remote-web-panel 变更（add-screen-viewport-border）

## ADDED Requirements

### Requirement: 视口外边框

副屏 SHALL 提供可选的视口外边框，用于 UI 走查；默认关闭。

#### Scenario: 打开开关

- **WHEN** 设置中打开「视口外边框（走查）」
- **THEN** 副屏四边各出现 1px 亮青色内描边，紧贴视口
- **AND** 不产生滚动条，不改变任何模块的尺寸或位置

#### Scenario: 默认关闭

- **WHEN** 用户从未修改该设置
- **THEN** 页面不绘制视口外边框，视觉与改动前一致

#### Scenario: 不拦截交互

- **WHEN** 用户点击控制条或屏幕任意位置
- **THEN** 事件照常触发，边框不参与命中测试

## MODIFIED Requirements

### Requirement: 副屏外观配置

`/api/screen/frame` SHALL 额外下发 `viewportBorder`（布尔），副屏据此显示或隐藏视口外边框。

#### Scenario: 配置生效

- **WHEN** Mac 端切换开关
- **THEN** 副屏在一次轮询内应用，无需刷新页面
