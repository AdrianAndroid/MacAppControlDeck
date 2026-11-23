# 提案：天气认证支持 API Key（默认），JWT 作为高级选项

## Why

JWT 需要生成密钥对、上传公钥、填写 `kid` / `iss` / `sub`，对只想看天气的用户太重。和风 API Key 目前仍可用，副屏每天约 288 次请求，量级很低；把它作为默认方式能显著降低配置成本。

JWT 仍保留：2027-01-01 起 API Key 会有每日请求限制，需要长期稳定或更高额度时可切换。

## What Changes

- 天气设置增加「认证方式」：**API Key（默认）** / **JWT（Ed25519）**。
- API Key：
  - 设置页只填 **API Host + API Key**；Key 存 macOS 钥匙串，不回显。
  - 请求头使用 `X-QW-Api-Key`。
- JWT：保留现有密钥对、公钥、`kid` / `iss` / `sub` 配置，作为高级选项。
- 认证方式、Host、城市写入本地配置；私钥与 API Key 只进钥匙串。
- 切换认证方式或保存新 Key 时清空天气缓存，避免复用旧数据。
- 页面与 `/api/weather` 的契约不变，仍不返回任何凭据。

**非目标**：

- 不删除 JWT 支持。
- 不改副屏布局与天气字段解析。
- 不做 API Key 的多账号管理。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：天气支持 API Key 与 JWT 两种认证方式。

## Impact

- 代码：`WeatherSettings`、`QWeatherAuth`、`QWeatherClient`、`WeatherService`、`ScreenSettingsView`。
- 测试：认证方式与 `canAuthenticate` 组合、JWT 既有用例。
- 数据：新增钥匙串条目 `qweather-api-key`；不写 UserDefaults。
- 兼容：已配置 JWT 的用户继续可用；没有配置的用户默认走 API Key。
