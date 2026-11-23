# remote-web-panel 变更（move-weather-secrets-to-file）

## ADDED Requirements

### Requirement: 天气凭据文件存储

天气 API Key 与 JWT 私钥 SHALL 保存在本机仅当前用户可读的 0600 文件中，不使用 macOS 钥匙串。

#### Scenario: 保存凭据

- **WHEN** 用户在副屏设置保存 API Key 或生成 JWT 密钥对
- **THEN** 凭据写入 `weather-secrets.json`，权限 0600
- **AND** 界面不回显 Key，不写日志

#### Scenario: 读取凭据

- **WHEN** 天气刷新或设置页渲染
- **THEN** 进程内缓存命中后不再读盘
- **AND** 只读取当前认证方式需要的凭据

#### Scenario: 不再弹钥匙串

- **WHEN** 应用重建或多次刷新天气
- **THEN** 不出现钥匙串授权或登录密码弹窗

#### Scenario: 升级提示

- **WHEN** 从使用钥匙串的旧版本升级
- **THEN** 设置页提示重新粘贴一次 API Key
- **AND** 旧钥匙串条目不再被读取
