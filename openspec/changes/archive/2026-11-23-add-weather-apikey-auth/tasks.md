# 任务：天气认证双模式

## 1. 凭据层

- [x] 1.1 `QWeatherAuth` 增加 API Key 的钥匙串读写/清除
- [x] 1.2 `WeatherAuthMode` 与 `WeatherConfig` 字段（authMode / hasAPIKey / hasPrivateKey）
- [x] 1.3 `canAuthenticate` 按模式校验；缓存 key 包含认证方式

## 2. 客户端与服务

- [x] 2.1 `QWeatherClient` 支持 `X-QW-Api-Key` 与 Bearer JWT 两种请求头
- [x] 2.2 `WeatherService` 按模式解析凭据；JWT 仍缓存 Token
- [x] 2.3 保存 Key / 切换模式 / 修改 Host 时清空缓存

## 3. 设置页

- [x] 3.1 认证方式分段选择器，默认 API Key
- [x] 3.2 API Key 输入（不回显已保存值）、保存、清除
- [x] 3.3 JWT 区域按模式显示/隐藏
- [x] 3.4 测试连接按当前模式校验并给出可读结果

## 4. 验证

- [x] 4.1 单测：两种模式的 `canAuthenticate`、既有 JWT 用例仍通过
- [x] 4.2 构建、覆盖安装、签名校验
- [ ] 4.3 真实 API Key 测试连接（等待用户提供 Host + Key）

> 4.3 是唯一未完成项：代码、UI、缓存失效与两种认证模式的逻辑均已测试；真实接口必须有用户的 Host 与 Key。

## 5. 归档

- [x] 5.1 同步 `openspec/specs/remote-web-panel/spec.md`
- [x] 5.2 更新 README 配置步骤
- [x] 5.3 归档到 `openspec/changes/archive/2026-11-23-add-weather-apikey-auth/`
