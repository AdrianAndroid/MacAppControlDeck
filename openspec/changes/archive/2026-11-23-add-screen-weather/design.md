# 设计：副屏天气（和风 JWT）

## 1. 认证：JWT（EdDSA）

- 用 CryptoKit `Curve25519.Signing.PrivateKey` 生成密钥对，私钥 32 字节原始表示存入钥匙串。
- 公钥按 Ed25519 SubjectPublicKeyInfo 输出 PEM：
  - DER 前缀 `302a300506032b6570032100` + 32 字节公钥，Base64 分行，加 `-----BEGIN PUBLIC KEY-----` / `-----END PUBLIC KEY-----`。
- JWT：
  - Header：`{"alg":"EdDSA","kid":"<kid>"}`
  - Payload：`{"iss":"<iss>","sub":"<sub>","iat":now-30,"exp":now+86400}`
  - `base64url(header) + "." + base64url(payload)` 作为签名输入，Ed25519 签名后再 base64url。
  - Token 缓存到 `exp - 60s`，不要每个请求重签。
- 不使用 API Key：2027-01-01 起 API Key 会有每日请求限制，且长期 bearer secret 泄露后一直有效。

## 2. 和风接口

所有请求都走账号专属 Host（控制台「设置 → API Host」），`https://<host>`。

- 实时：`GET /weather/v1/current/{lat}/{lon}`
- 3 天：`GET /weather/v1/daily/{lat}/{lon}`，取返回列表前 3 项
- 城市搜索：`GET /geo/v2/city/lookup?location=<关键词>&number=10`

坐标统一保留两位小数；时间字段按 ISO 8601 解析后在手机/Mac 本地时区展示，不依赖 `localTime` 查询参数。

### 2.1 返回字段的不确定性

和风新版文档只给出字段描述，未给完整 JSON schema。已确认存在 `temperature.value` 与 `condition.text`。因此解析器按"优先新结构、回退旧字段"实现：

- 当前温度：`temperature.value` → `temp`
- 现象文本：`condition.text` → `text` / `weather`
- 现象图标：`condition.icon` → `icon`
- 体感：`feelsLike.value` → `feelsLike`
- 湿度：`humidity`；≤1 视为 0–1 比例并转百分比
- 每日最高/最低：`temperature.max.value` / `temperature.min.value` → `tempMax` / `tempMin`
- 每日现象：`day.condition.text` / `day.condition.icon` → `textDay` / `iconDay`
- 日期：`forecastStartTime`（ISO 8601）→ `date` / `fxDate`

解析失败时返回 `decode-failed` 与可读错误，不写入缓存；设置页「测试连接」展示错误，便于用真实响应对齐字段。

## 3. 服务与缓存

- `WeatherService` 为 actor：单飞（相同请求只发一次）、10 分钟缓存、失败后 60 秒内不重试。
- 失败但已有缓存：返回缓存并标 `stale: true`；页面显示「已过期」。
- 未配置凭据/城市：返回 `reason: "not-configured"`，页面不显示天气块，不影响时钟/月历。
- 页面每 10 分钟请求 `/api/weather`；`document.hidden` 时暂停。
- 服务端每次最多打 2 个和风请求（current + daily），城市搜索只在设置页手动触发。

## 4. `/api/weather` 契约

```json
{
  "ok": true,
  "stale": false,
  "updatedAt": "2026-11-23T12:30:00Z",
  "city": "北京",
  "now": { "temp": 23, "text": "多云", "icon": "101", "feelsLike": 22, "humidity": 54 },
  "today": { "max": 26, "min": 18, "precipProbability": 20, "text": "多云" },
  "daily": [
    { "date": "2026-11-24", "text": "晴", "icon": "100", "max": 25, "min": 17, "precipProbability": 10 }
  ],
  "attribution": "和风天气"
}
```

- 公开只读，不需要 token（与副屏一致）。
- 不返回坐标、Key、JWT、Host。
- 失败：`{"ok":false,"reason":"not-configured"|"upstream"|"decode-failed","message":"..."}`，HTTP 仍为 200，页面按原因降级。

## 5. 布局（L2 / P1）

- 横屏（L2）：
  - 左列时钟约 46%，右侧纵向「实时天气（固定高）→ 月历（1fr）→ 3 天预报（固定高）」。
  - 实时天气：大号温度 + 现象 + 今日高低温 + 降水概率。
  - 3 天预报：三等分横向单元格，每格「星期 / 图标 / 高低温」。
- 竖屏（P1）：时钟 40% → 实时天气 → 月历 1fr → 3 天预报，纵向排布。
- 极窄屏（<380）沿用竖屏排布，天气字号走 `vw` 分支。
- 天气图标：内联单色 SVG（晴/云/雨/雪/雾/雷），不引入彩色 emoji。
- 红色仍只用于月份与今天；天气温度用白色，图标用灰白。

## 6. 设置与凭据

- 新设置页「副屏」：副屏地址卡片 + 天气配置。
- 天气配置字段：开关、API Host、`iss`、`sub`、`kid`、公钥展示/复制、城市搜索、测试连接。
- 私钥：钥匙串 `kSecClassGenericPassword`，service `com.zhaojian.MacAppControlDeck.weather`，account `qweather-private-key`；不写 UserDefaults、不进日志。
- 城市与 Host/ID 存 UserDefaults；页面和 `/api/weather` 不包含这些值。
- 「重新生成密钥对」会明确提示：旧公钥立即失效，需要重新上传。

## 7. 已知限制

- 和风 v1 JSON 字段未在文档中给全，首次接入必须用真实凭据执行一次「测试连接」校准。
- 天气无法做到秒级"实时"：和风更新频率由数据源决定，页面只展示 `updatedAt`。
- HTTP 副屏无法保持常亮；天气不影响该限制。
- 和风免费额度与控制台条款可能变化，应用只在启用天气时请求，并在页面署名。
