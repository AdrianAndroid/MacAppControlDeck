# remote-web-panel 变更（cache-weather-keychain-reads）

## ADDED Requirements

### Requirement: 天气凭据读取策略

天气凭据 SHALL 保持在 macOS 钥匙串中，并在进程内缓存读取结果，避免每次轮询或渲染都触发系统授权。

#### Scenario: 一次运行一次读取

- **WHEN** 应用在一次运行中多次刷新天气或重绘设置页
- **THEN** 钥匙串最多读取一次
- **AND** 后续使用内存缓存，不再弹窗

#### Scenario: 只读当前认证方式

- **WHEN** 认证方式为 API Key
- **THEN** 不读取 JWT 私钥
- **WHEN** 认证方式为 JWT
- **THEN** 不读取 API Key

#### Scenario: 授权提示

- **WHEN** 系统弹出钥匙串授权
- **THEN** 设置页提示用户选择「始终允许」
- **AND** 保存、清除或重新生成凭据后缓存立即更新
