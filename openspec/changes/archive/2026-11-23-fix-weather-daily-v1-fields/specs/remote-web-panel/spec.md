# remote-web-panel 变更（fix-weather-daily-v1-fields）

## ADDED Requirements

### Requirement: 和风 v1 日预报字段兼容

3 天预报 SHALL 正确解析和风 v1 的 `days`、`daytime.condition.code`、`temperatureMax/Min.value` 与降水概率字段。

#### Scenario: 真实 v1 响应

- **WHEN** 日预报返回 `days[].daytime.condition.text/code`
- **THEN** 页面显示对应天气图标与高低温
- **AND** 不再显示「—」或统一云图标

#### Scenario: 旧字段回退

- **WHEN** 响应只含 `daily[].day.condition` 或 `textDay/iconDay`
- **THEN** 仍按旧字段解析，不回归
