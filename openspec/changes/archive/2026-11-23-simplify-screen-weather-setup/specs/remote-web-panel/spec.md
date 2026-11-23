# remote-web-panel 变更（simplify-screen-weather-setup）

## ADDED Requirements

### Requirement: 天气配置引导与校验

副屏天气设置 SHALL 用单一步骤化界面完成配置，并在请求前拦截明显错误的 API Host。

#### Scenario: 填入示例 Host

- **WHEN** 用户把文档示例 Host（如 `h2a9cf3mhs.xy.qweatherapi.com`）填入 API Host
- **THEN** 界面立即提示这是示例，要求换成控制台「设置」里的专属 Host
- **AND** 测试连接与城市搜索保持禁用或给出同一提示，不发起请求

#### Scenario: DNS 解析失败

- **WHEN** 城市搜索或测试连接遇到无法解析的 Host
- **THEN** 显示「无法解析 API Host：请确认它是控制台设置里的专属域名，不是文档示例」
- **AND** 不显示系统原始英文/网络错误

#### Scenario: 三步配置

- **WHEN** 用户打开「设置 → 副屏」
- **THEN** 天气配置按「填写和风凭据 → 选择城市 → 测试并显示」三步呈现
- **AND** JWT 选项默认收起，只在用户主动切换后显示

#### Scenario: 测试成功

- **WHEN** 测试连接成功
- **THEN** 自动打开「在副屏显示天气」开关
- **AND** 只保留一条成功提示
