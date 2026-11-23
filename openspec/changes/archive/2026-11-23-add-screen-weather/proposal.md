# 提案：副屏加入天气（实时 + 3 天预报）

## Why

副屏现在只有时钟和月历。把它挂在桌面/床头时，温度、天气现象和未来几天的趋势是最常被扫一眼的信息；来回切手机查天气反而破坏"副屏"的价值。

和风天气（QWeather）国内数据质量好，2026 年已全面改用账号专属 API Host 与 Ed25519 JWT 认证。按 JWT 接入可以避免 2027 年 API Key 的每日限制，也避免把长期 bearer secret 存在本机。

## What Changes

- 新增「副屏天气」能力：
  - 实时：温度、天气现象、体感、今日最高/最低、降水概率
  - 预报：未来 3 天（图标 + 最高/最低温）
  - 底部：更新时间 + 「和风天气」署名
- Mac 端新增 `WeatherService`：
  - 使用和风 **v1** 接口：`/weather/v1/current/{lat}/{lon}`、`/weather/v1/daily/{lat}/{lon}`、`/geo/v2/city/lookup`
  - JWT（EdDSA）认证：请求头 `Authorization: Bearer <JWT>`，Token 24 小时内复用
  - 10 分钟缓存、并发合并、失败退避与 `stale` 标记
- 认证与配置：
  - API Host、开发者 ID（`iss`）、项目 ID（`sub`）、凭据 ID（`kid`）保存在本地配置
  - Ed25519 私钥保存在 **macOS 钥匙串**；应用可生成密钥对并展示公钥 PEM 供粘贴到和风控制台
  - 城市通过 GeoAPI 搜索，保存「名称 + 经纬度」
- 服务端新增只读接口 `GET /api/weather`，供副屏页面轮询；不暴露 Key、私钥、完整经纬度（只返回城市名与天气）。
- 副屏布局（L2 / P1）：
  - 横屏：左侧时钟（约 46%），右侧自上而下「实时天气 → 月历 → 3 天预报」
  - 竖屏：时钟 → 实时天气 → 月历 → 3 天预报，纵向均分
  - 极窄屏继续按 `vw` 收窄，保持不滚动
- 设置新增「副屏」标签页：副屏地址、天气开关、和风凭据、城市搜索、测试连接。
- 菜单栏「电脑控制」新增「副屏设置…」，沿用既有「打开副屏」入口。

**非目标**：

- 不做手机 GPS 定位（HTTP 下不可用），不做 IP 定位。
- 不做逐小时预报、分钟级降水、天气预警、空气质量。
- 不把和风 Key/私钥写入页面或下发给手机。
- 不引入第三方天气 SDK，不新增 SwiftPM 依赖。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：副屏新增天气区、`/api/weather` 与「副屏」设置页。

## Impact

- 代码：
  - 新增 `Modules/RemoteControl/Weather/*`（配置、JWT、服务、解析、设置页）
  - 新增 `Store/KeychainStore.swift`
  - 修改 `Panel/ScreenHTML.swift`、`Server/APIRouter.swift`、`UI/SettingsView.swift`、`App/DeckApp.swift`、`Modules/RemoteControl/RemoteControlModule.swift`
- 网络：首次出现主动出网请求（仅和风 API），只在启用天气且有城市时发生。
- 隐私：请求只携带经纬度与 JWT；页面只拿到城市名与天气。凭据仅存本机。
- 权限：不新增系统权限。
- 入口：沿用「打开副屏」（`screen.open`），不新增内置操作按钮（R0 子能力规则）。
