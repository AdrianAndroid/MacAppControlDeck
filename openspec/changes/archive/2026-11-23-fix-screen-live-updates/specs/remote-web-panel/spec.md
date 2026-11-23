# remote-web-panel 变更（fix-screen-live-updates）

## ADDED Requirements

### Requirement: 副屏版本自检与刷新

副屏 SHALL 在运行期间检测 Mac 端页面版本，并在版本变化时自动重载；同时提供手动刷新入口。

#### Scenario: Mac 端更新页面

- **WHEN** 页面同步时间时发现 `/api/time.screenVersion` 与自身版本不同
- **THEN** 自动重载到 `/screen/?v=<新版本>&t=<时间戳>`
- **AND** 用户不需要手动关闭页面

#### Scenario: 手动刷新

- **WHEN** 用户点按屏幕唤出控制条并点「↻」
- **THEN** 页面以带版本与时间戳的地址重载

#### Scenario: 回到前台

- **WHEN** 手机从后台或锁屏回到页面
- **THEN** 立即同步 Mac 时间并刷新一次天气
- **AND** 时钟继续逐帧更新

#### Scenario: 刷新频率

- **WHEN** 页面保持前台
- **THEN** 每 5 分钟拉取一次天气，Mac 端缓存 5 分钟
- **AND** 页面明确显示最近更新时间，不宣称秒级实时天气
