# 提案：副屏增加未来 4 小时预报

## Why

副屏只有「现在」和「未来 5 天」，缺中间粒度。和风 v1 的 `/weather/v1/hourly` 已可用（实测 24/72/168 小时），加一条紧凑小时条能补充「接下来几小时」的信息。

## What Changes

- Mac 端新增小时预报请求（默认 24 小时，可选失败），与实时/日预报并行；缓存 5 分钟。
- `/api/weather` 增加 `hourly`（最多 8 条），失败时不影响其余天气。
- 副屏天气栏在体感下面、5 天预报表上面插入**两行紧凑小时条**：时间一行，图标+温度一行；5 格（现在 + 4 小时）。
- 小时标签按 Mac 时区转换；无小时数据时隐藏整条。
- 矮屏（可用高度 ≤ 430px）压缩天气主视觉和预报行，保证小时条、5 天表和更新时间都不出视口。
- 页面版本提升到 `2026-11-23.10`。

**非目标**：

- 不做 24 小时横向滚动或完整小时列表。
- 不新增降水概率/风力到小时条（只显示图标与温度）。
- 不改变 5 天预报与现有接口字段。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：副屏天气栏增加小时预报条。

## Impact

- 代码：`WeatherModels.swift`、`QWeatherClient.swift`、`WeatherService.swift`、`ScreenHTML.swift`、`APIRouterTests.swift`、`QWeatherTests.swift`。
- 网络：每次天气刷新多请求一次 hourly；失败自动降级。
