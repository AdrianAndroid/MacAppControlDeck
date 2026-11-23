# remote-web-panel 变更（tint-panel-clock-red）

## MODIFIED Requirements

### Requirement: 横屏系统时钟

面板 SHALL 在横屏布局下于标题栏显示手机本地系统时间，格式为 `YYYY年MM月DD日 星期X HH:mm:ss`，并每秒刷新；竖屏下 MUST NOT 显示该时钟。时钟 MUST 使用鲜艳红色强调，在深色面板上清晰可读。

#### Scenario: 横屏显示时间

- **WHEN** 面板在横屏（`orientation: landscape`）下渲染主界面
- **THEN** 标题栏显示 `2026年11月23日 星期一 10:33:21` 形式的本地时间，颜色为鲜艳红 `#ff3b30` 且加粗
- **AND** 时钟位于标题与连接状态之间，标题栏在 568×320 及以上尺寸不换行、不溢出

#### Scenario: 每秒刷新

- **WHEN** 面板在横屏下持续打开
- **THEN** 时钟每秒更新一次秒值与星期，数字宽度保持稳定不跳动

#### Scenario: 竖屏隐藏

- **WHEN** 面板处于竖屏
- **THEN** 标题栏不显示时钟，仅保留标题与连接状态
