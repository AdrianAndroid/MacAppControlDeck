# 提案：副屏天气支持使用 Mac 当前位置

## Why

手动搜索城市是配置天气的最后一步摩擦。副屏页面是 HTTP，手机浏览器无法调用定位；但 Mac 端可以使用系统定位服务，一次授权后直接得到城市。

## What Changes

- 设置 → 副屏的城市区新增「使用当前位置」按钮。
- Mac 端通过 CoreLocation 获取一次粗略坐标（公里级），再用和风 GeoAPI 反查城市并选中。
- 首次使用会请求 macOS 定位权限；拒绝或不可用时给出可执行提示，保留手动搜索。
- 定位超时、系统定位关闭、无 Wi-Fi 导致失败时，回退到搜索，不阻塞其他设置。
- Info.plist 增加定位用途说明。
- 坐标只在本机与和风之间使用，不下发副屏页面。

**非目标**：

- 不做持续定位、后台定位或轨迹记录。
- 不使用 IP 定位（多一个第三方依赖，精度与隐私都更差）。
- 不改变手机页面的定位能力。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：天气城市支持 Mac 定位。

## Impact

- 代码：新增 `WeatherLocationProvider`；修改 `ScreenSettingsView`、`Info.plist`。
- 权限：新增 macOS 定位（仅使用期间，一次性）。
- 网络：坐标发给和风 GeoAPI；不新增第三方服务。
