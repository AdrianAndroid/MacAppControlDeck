# remote-web-panel 变更（speed-up-screen-refresh）

## MODIFIED Requirements

### Requirement: 副屏版本自检与刷新

副屏 SHALL 在运行期间检测 Mac 端页面版本并自动重载，同时以更短的轮询间隔感知设置变化。

#### Scenario: 设置保存后

- **WHEN** 用户在 Mac 设置保存凭据或选择城市
- **THEN** 若凭据与城市齐全，自动执行一次测试并打开天气开关
- **AND** 副屏在下一次轮询（不超过 30 秒）内拉取并显示新配置
- **AND** Mac 端天气缓存仍为 5 分钟，不额外请求和风

#### Scenario: 时间同步

- **WHEN** 页面保持前台
- **THEN** 每 60 秒同步一次 Mac 时间
- **AND** 回到前台立即同步

#### Scenario: 手动刷新

- **WHEN** 用户点按控制条「↻」
- **THEN** 页面立即带版本与时间戳重载
