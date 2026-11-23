# 提案：测试连接后立即刷新副屏

## Why

即使页面 30 秒轮询，用户在 Mac 点「测试连接」或保存凭据后，仍要等下一次轮询才能看到结果。需要一个主动通知通道，让副屏立即刷新。

## What Changes

- 新增只读长轮询接口 `GET /api/screen/events?since=<revision>`，最多挂起 15 秒。
- 新增进程内 `ScreenEventHub`：保存凭据、清除 Key、选择城市、测试连接完成时递增 revision 并唤醒等待者。
- 副屏页面常驻一个长轮询：收到 revision 变化立即刷新时间与天气；连接结束 800ms 后重连。
- 页面版本提升到 `2026-11-23.6`。

**非目标**：

- 不引入 WebSocket/SSE，不做双向通信。
- 不推送天气字段，只通知“该刷新了”。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：设置变更后的即时刷新。

## Impact

- 代码：新增 `ScreenEventHub`；修改 `APIRouter`、`ScreenHTML`、`ScreenSettingsView`。
- 网络：每个副屏页面保持一条最多 15 秒的长轮询连接；局域网开销很小。
