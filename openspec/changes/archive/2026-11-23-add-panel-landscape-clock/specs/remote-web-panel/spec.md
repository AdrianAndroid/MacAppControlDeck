# remote-web-panel 变更（add-panel-landscape-clock）

## ADDED Requirements

### Requirement: 横屏系统时钟

面板 SHALL 在横屏布局下于标题栏显示手机本地系统时间，格式为 `YYYY年MM月DD日 星期X HH:mm:ss`，并每秒刷新；竖屏下 MUST NOT 显示该时钟。

#### Scenario: 横屏显示时间

- **WHEN** 面板在横屏（`orientation: landscape`）下渲染主界面
- **THEN** 标题栏右侧显示 `2026年11月23日 星期一 10:33:21` 形式的本地时间
- **AND** 时钟位于连接状态标签旁，不遮挡标题与状态

#### Scenario: 每秒刷新

- **WHEN** 面板在横屏下持续打开
- **THEN** 时钟每秒更新一次秒值与星期，数字宽度保持稳定不跳动

#### Scenario: 竖屏隐藏

- **WHEN** 面板处于竖屏
- **THEN** 标题栏不显示时钟，仅保留标题与连接状态
- **AND** 标题栏不因此换行或溢出

#### Scenario: 旋转切换

- **WHEN** 设备在横屏与竖屏之间旋转
- **THEN** 时钟随布局切换显示或隐藏，时间值与本地时间保持一致
