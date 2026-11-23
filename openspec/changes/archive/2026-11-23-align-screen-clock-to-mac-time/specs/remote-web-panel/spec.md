# remote-web-panel 变更（align-screen-clock-to-mac-time）

## ADDED Requirements

### Requirement: 副屏时间以 Mac 为准

副屏 SHALL 以 Mac 的本地日期与时间绘制模拟时钟、月历和「今天」高亮，不依赖手机的日期或时区。

#### Scenario: 手机日期与 Mac 不同

- **WHEN** 手机的系统日期或时区与 Mac 不一致
- **THEN** 副屏时钟显示 Mac 的时分秒，月历高亮 Mac 的「今天」
- **AND** 当前月份与 Mac 的月份一致，不出现错日或错月

#### Scenario: 时间同步

- **WHEN** 页面加载、每 10 分钟或从后台回到前台
- **THEN** 请求 `/api/time` 并用返回的 epoch 与时区偏移重建墙钟
- **AND** 同步过程不阻塞时钟，不重置用户正在浏览的其他月份

#### Scenario: 服务不可达

- **WHEN** `/api/time` 请求失败
- **THEN** 继续使用上一次同步的基准；首次失败时退回手机本地时间
- **AND** 时钟与月历仍正常显示，不出现错误提示或空白

#### Scenario: 时间接口隔离

- **WHEN** 任意设备请求 `/api/time`
- **THEN** 只返回 Mac 的时间、时区与 ISO 字符串
- **AND** 不包含按钮、配对、城市、凭据或文件路径
- **AND** 响应头包含 `Cache-Control: no-store, must-revalidate`
