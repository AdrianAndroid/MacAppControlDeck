# 任务：副屏天气（和风 JWT）

## 1. 凭据与 JWT

- [x] 1.1 `KeychainStore`：读写/删除通用密码项
- [x] 1.2 `QWeatherAuth`：生成 Ed25519 密钥对、输出 SPKI PEM 公钥
- [x] 1.3 JWT 生成（EdDSA、kid/iss/sub、iat/exp、base64url、24h 缓存）
- [x] 1.4 单元测试：claims、签名可被公钥验证、过期时间

## 2. 天气服务

- [x] 2.1 `WeatherSettings`：Host/iss/sub/kid/城市/开关持久化
- [x] 2.2 `QWeatherClient`：current、daily、city lookup，JWT 请求头，10s 超时
- [x] 2.3 容错解析（temperature.value / condition.text / day.condition 等，含旧字段回退）
- [x] 2.4 `WeatherService`：10 分钟缓存、单飞、失败退避、stale 降级
- [x] 2.5 fixture 测试：实时、3 天、城市搜索、异常响应

## 3. 服务端与设置

- [x] 3.1 `GET /api/weather`（公开只读，不含坐标/凭据）
- [x] 3.2 新增设置标签页「副屏」：地址卡片、天气开关、凭据、公钥、城市搜索、测试连接
- [x] 3.3 菜单栏「副屏设置…」与 `macappcontroldeck://settings/screen` 深链接
- [x] 3.4 路由测试：未配置、成功、stale、decode-failed

## 4. 副屏页面

- [x] 4.1 L2 横屏布局：时钟 46% + 右侧「实时天气 / 月历 / 3 天」
- [x] 4.2 P1 竖屏布局与 <380 窄屏回退
- [x] 4.3 单色 SVG 天气图标与图标码映射
- [x] 4.4 页面每 10 分钟拉 `/api/weather`，隐藏暂停，失败显示「天气暂不可用」/「已过期」
- [x] 4.5 署名「和风天气」与更新时间
- [x] 4.6 无天气数据时不占位、不破坏时钟/月历布局

## 5. 验证

- [x] 5.1 `swift build -c release` 与相关测试通过
- [x] 5.2 无头 Chrome 844×390 / 500×757 / 320 宽截图验收
- [x] 5.3 固定签名构建、覆盖安装、`verify-signing.sh` 通过
- [ ] 5.4 用真实和风凭据执行「测试连接」并校准解析（等待用户填入 Host/kid/iss/sub 并上传公钥后完成）

> 5.4 是唯一未完成项：代码、路由、JWT、解析与布局均已测试；真实字段校准必须有用户的和风凭据，未验证前不谎报已对接成功。

## 6. 归档

- [x] 6.1 同步 `openspec/specs/remote-web-panel/spec.md`
- [x] 6.2 README 功能、设置说明、归档链接
- [x] 6.3 归档到 `openspec/changes/archive/2026-11-23-add-screen-weather/`
