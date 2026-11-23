# 设计：天气认证双模式

## 1. 认证模式

```swift
enum WeatherAuthMode: String { case apiKey, jwt }
```

- 默认 `apiKey`；存储在 UserDefaults `screen.weather.authMode`。
- 已配置过 JWT 且没有 API Key 的旧配置：读取时如果 `authMode` 为空，默认 `apiKey`；用户可在设置里切回 JWT，原有 `kid/iss/sub` 与私钥保留。

## 2. 凭据存储

| 方式 | 存储 | 请求头 |
| --- | --- | --- |
| API Key | 钥匙串 service `com.zhaojian.MacAppControlDeck.weather` / account `qweather-api-key` | `X-QW-Api-Key: <key>` |
| JWT | 钥匙串 account `qweather-private-key` + UserDefaults 的 `iss/sub/kid` | `Authorization: Bearer <JWT>` |

- API Key 不回显：设置页只显示「已保存 / 未保存」，可替换或清除。
- 两者都不写日志、不下发页面。

## 3. 客户端与缓存

- `QWeatherClient` 接收 `Credential` 枚举（`.apiKey(String)` / `.jwt(String)`），统一设置请求头。
- `WeatherService` 只在 JWT 模式生成、缓存 Token；API Key 模式每次从钥匙串读取（钥匙串调用开销可接受，且能在替换后立即生效）。
- `canAuthenticate`：
  - API Key：Host 非空且钥匙串有 Key。
  - JWT：Host 非空、`iss/sub/kid` 非空且钥匙串有私钥。
- 保存新 Key、切换认证方式、修改 Host/ID 都调用 `WeatherService.invalidate()`。
- 缓存 key 包含认证方式与城市/凭据身份，防止跨模式复用。

## 4. 设置页

- 「认证方式」用分段选择器，默认 API Key。
- API Key 模式：Host + SecureField + 「保存」/「清除」，并提示 Key 只存钥匙串。
- JWT 模式：保留现有 Host、`iss/sub/kid`、生成密钥对、公钥复制。
- 「测试连接」逻辑不变，只按当前模式校验凭据。

## 5. 已知限制与取舍

- 和风官方说明 API Key 从 2027-01-01 起限制每日请求量；具体数字未公布。副屏每天约 288 次，个人使用大概率足够，但不承诺。
- API Key 是长期 bearer secret；泄露后需在控制台轮换。它只存在本机钥匙串，不随页面下发。
- JWT 继续保留，切换成本只是重新填 `kid/iss/sub` 与上传公钥。
