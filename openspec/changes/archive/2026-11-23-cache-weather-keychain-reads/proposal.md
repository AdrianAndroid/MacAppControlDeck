# 提案：减少天气凭据的钥匙串读取与弹窗

## Why

天气设置把 API Key 存在 macOS 钥匙串。应用每次重建后签名变化，钥匙串会再次询问授权；而 `WeatherSettings.config` 在每次页面渲染和每 5 分钟天气轮询时都会读取 Key，放大了弹窗频率。

## What Changes

- 钥匙串读取结果在进程内缓存：一次运行最多读一次。
- 只读取当前认证方式需要的凭据：API Key 模式不碰 JWT 私钥，JWT 模式不碰 API Key。
- 保存/清除 Key 或重新生成密钥对时同步更新缓存。
- 设置页提示：系统询问时选择「始终允许」。

**非目标**：

- 不改变凭据仍存 macOS 钥匙串这一事实。
- 不改为明文文件存储。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：天气凭据读取与提示。

## Impact

- 代码：`QWeatherAuth.swift`、`WeatherSettings.swift`、`ScreenSettingsView.swift`。
- 用户可见：每次运行最多一次钥匙串授权，而不是每次轮询一次。
