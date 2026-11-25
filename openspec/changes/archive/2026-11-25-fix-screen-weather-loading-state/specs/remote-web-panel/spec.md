# remote-web-panel Delta

## MODIFIED Requirements

### Requirement: 副屏天气展示

首次请求尚未返回时，天气栏 SHALL 显示「天气加载中…」，不得显示失败文案。

#### Scenario: 首次加载
- **WHEN** 页面刚打开且 `/api/weather` 尚未返回
- **THEN** 天气栏显示「天气加载中…」
- **AND** 返回成功后立即切换为真实天气数据

#### Scenario: 失败且无缓存
- **WHEN** 请求失败且没有可用缓存，上游也未给出明确原因
- **THEN** 天气栏显示「天气加载失败，正在重试…」
- **AND** 8 秒后自动重试一次；重试期间显示「天气加载中…」；成功后清除重试定时器

#### Scenario: 断网
- **WHEN** Mac 断网导致上游请求失败
- **THEN** 显示「Mac 当前无法联网」等服务端给出的具体原因
- **AND** 时钟与月历不受影响
