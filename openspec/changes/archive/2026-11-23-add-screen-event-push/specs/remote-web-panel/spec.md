# remote-web-panel 变更（add-screen-event-push）

## ADDED Requirements

### Requirement: 设置变更即时通知副屏

Mac 端 SHALL 在天气凭据、城市或测试结果变化时通知副屏，使页面立即刷新。

#### Scenario: 点击测试连接

- **WHEN** 用户在设置页点击「测试连接」并完成
- **THEN** 副屏在 1 秒内收到通知并重新拉取天气
- **AND** 不需要等待 30 秒轮询或手动点「↻」

#### Scenario: 保存凭据或选择城市

- **WHEN** 用户保存 API Key、清除 Key 或选择城市
- **THEN** 同样触发一次即时刷新

#### Scenario: 长轮询

- **WHEN** 页面保持前台
- **THEN** 维持一条最多 15 秒的长轮询连接
- **AND** 超时或断开后 800ms 重连，不阻塞时钟

#### Scenario: 无变化

- **WHEN** 15 秒内没有 revision 变化
- **THEN** 返回当前 revision，页面静默重连，不刷新数据
