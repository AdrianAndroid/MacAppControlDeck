# 提案：副屏时钟与月历对齐 Mac 时间

## Why

副屏页面目前用手机本地时间计算时钟与「今天」，手机日期或时区与 Mac 不一致时，月历会高亮错误的日期，甚至显示不同月份。副屏是 Mac 的附属显示，时间基准应以 Mac 为准。

## What Changes

- 新增只读接口 `GET /api/time`，返回 Mac 的当前时间：
  - `epoch`（Unix 秒）、`offsetMinutes`（Mac 时区偏移）、本地年月日时分秒、时区标识与 ISO 字符串。
- 副屏页面启动时拉取 `/api/time`，用「Mac 墙钟」计算：
  - 模拟时钟的时/分/秒
  - 月历的当前年月、「今天」高亮、月份自动回到当月
  - 未来 3 天预报的「今天/明天/后天/周几」标签
- 每 10 分钟重新同步一次，回到前台时也同步；网络失败时退回手机本地时间，不阻塞时钟/月历。
- 页面版本提升到 `2026-11-23.3`。

**非目标**：

- 不修改 Mac 的系统时间，不做 NTP。
- 不改变天气接口的时区语义（和风返回的日期仍是所选城市的本地日期）。
- 不把 Mac 时区或时间写入任何持久配置。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：副屏时钟与月历以 Mac 时间为基准。

## Impact

- 代码：`Server/APIRouter.swift`、`Panel/ScreenHTML.swift`。
- 测试：`/api/time` 路由与页面引用；现有 `/api/weather`、`/screen/` 用例保持。
- 隐私：接口只返回时间，不含设备、城市或凭据。
- 权限：无新增。
