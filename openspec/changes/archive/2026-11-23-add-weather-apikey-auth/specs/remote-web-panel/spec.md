# remote-web-panel 变更（add-weather-apikey-auth）

## ADDED Requirements

### Requirement: 天气认证方式

副屏天气 SHALL 支持 API Key 与 JWT（Ed25519）两种认证方式，默认 API Key；两种方式的凭据都只保存在 Mac 端。

#### Scenario: API Key 配置

- **WHEN** 用户选择「API Key」并填入 API Host 与 Key
- **THEN** 设置页保存 Key 到 macOS 钥匙串，不在界面回显
- **AND** 天气请求使用 `X-QW-Api-Key` 请求头
- **AND** 不需要生成密钥对或填写 `iss/sub/kid`

#### Scenario: JWT 配置

- **WHEN** 用户切换到「JWT」
- **THEN** 设置页显示 Host、`iss`、`sub`、`kid` 与公钥管理
- **AND** 天气请求使用 `Authorization: Bearer <JWT>`

#### Scenario: 切换认证方式

- **WHEN** 用户从一种认证方式切换到另一种
- **THEN** 天气缓存立即失效，下一次请求使用新模式
- **AND** 另一种模式的已保存凭据保留，切回时无需重新填写

#### Scenario: 替换或清除 API Key

- **WHEN** 用户保存新 Key 或点「清除」
- **THEN** 钥匙串条目被更新或删除，缓存失效
- **AND** 页面不会得到 Key、Host 或坐标
