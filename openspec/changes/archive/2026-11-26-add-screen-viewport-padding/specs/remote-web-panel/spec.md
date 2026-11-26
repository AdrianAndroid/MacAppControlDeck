# remote-web-panel 变更（add-screen-viewport-padding）

## ADDED Requirements

### Requirement: 视口铺满与可调内边距

副屏 SHALL 默认把内容铺满整个视口，并允许在 Mac 端分别设置上 / 右 / 下 / 左内边距。

#### Scenario: 默认铺满

- **WHEN** 用户从未修改内边距设置
- **THEN** 副屏内容四边贴住视口（叠加设备 safe-area），不再有 `2.6u` 浮动外边距与 `3u` 固定留白
- **AND** 横屏三栏、竖屏时钟 / 天气 / 月历均不被裁切、不产生滚动

#### Scenario: 四边独立调节

- **WHEN** 在 设置 → 副屏 → 外观 调整「视口内边距」的上 / 右 / 下 / 左
- **THEN** 副屏按对应像素值内缩，四边互不影响，取值范围 0–120px
- **AND** 修改经 `ScreenEventHub` 通知，副屏在下一次轮询内应用

#### Scenario: 归零

- **WHEN** 点击「归零」
- **THEN** 四边内边距同时回到 0，内容重新铺满视口

#### Scenario: 持久化与下发

- **WHEN** 重启 App 或重新读取配置
- **THEN** 四个内边距值从 `UserDefaults` 恢复，并由 `GET /api/screen/frame` 原样下发
- **AND** 超出 0–120 的值在设置层与配置层都被收敛

## MODIFIED Requirements

### Requirement: 视口外边框（走查）

视口外边框 SHALL 仍紧贴视口四边绘制；内容铺满时边框落在卡片边缘之上，不占布局、不吃点击。
