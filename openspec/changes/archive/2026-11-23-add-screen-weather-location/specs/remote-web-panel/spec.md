# remote-web-panel 变更（add-screen-weather-location）

## ADDED Requirements

### Requirement: 使用 Mac 当前位置选择城市

天气设置 SHALL 允许用户用 Mac 的系统定位一键选择城市；定位失败时保留手动搜索。

#### Scenario: 首次定位

- **WHEN** 用户点击「使用当前位置」且尚未授权
- **THEN** 系统弹出定位权限请求
- **AND** 允许后取一次公里级坐标，并用和风 GeoAPI 反查城市
- **AND** 自动选中返回的第一个城市，清空搜索词

#### Scenario: 拒绝或关闭定位

- **WHEN** 用户拒绝授权，或系统定位服务关闭
- **THEN** 显示「未授权定位 / 定位服务未开启」并提供手动搜索
- **AND** 不重复弹窗、不阻塞其他设置

#### Scenario: 定位超时或无结果

- **WHEN** 12 秒内没有拿到坐标，或和风没有返回城市
- **THEN** 显示定位失败原因，保留搜索框
- **AND** 允许用户继续手动搜索

#### Scenario: 未配置凭据

- **WHEN** API Host 或 API Key 未配置
- **THEN**「使用当前位置」不可用，并提示先完成凭据

#### Scenario: 坐标隐私

- **WHEN** 定位成功
- **THEN** 坐标只用于 Mac 端向和风反查城市
- **AND** 不写入副屏页面、`/api/weather` 或日志
