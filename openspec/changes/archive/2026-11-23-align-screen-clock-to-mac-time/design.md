# 设计：副屏使用 Mac 墙钟

## 1. `/api/time` 契约

```json
{
  "epoch": 1795500600.123,
  "offsetMinutes": 480,
  "year": 2026, "month": 11, "day": 23,
  "hour": 14, "minute": 30, "second": 0,
  "timeZone": "Asia/Shanghai",
  "iso": "2026-11-23T14:30:00+08:00"
}
```

- 公开只读，`Cache-Control: no-store`，不含任何凭据或城市信息。
- 用 `Date()`、`TimeZone.current` 与 `Calendar.current` 计算；`offsetMinutes = secondsFromGMT / 60`。
- `epoch` 使用 Unix 秒（含小数），页面只用它做偏移基准。

## 2. 页面如何得到「Mac 墙钟」

页面不能把 `epoch` 直接交给手机时区解释，否则跨时区会显示错日期。做法：

1. 记录 `macEpoch`（Mac Unix 秒）、`macOffsetMinutes`（Mac 时区偏移）、`fetchedAt`（手机 `Date.now()`）。
2. 任意时刻：
   ```js
   const wallMs = (macEpoch + macOffsetMinutes * 60) * 1000 + (Date.now() - fetchedAt);
   const wall = new Date(wallMs);
   ```
3. 统一用 **UTC getter** 读取墙钟：`getUTCFullYear/Month/Date/Hours/Minutes/Seconds`。
   这样即使手机时区不同，读到的仍是 Mac 的年月日时分秒。
4. 时钟、月历、今天高亮、3 天标签全部基于 `wall`。

## 3. 同步与降级

- 页面加载时请求 `/api/time`；之后每 10 分钟同步一次，`visibilitychange` 回到前台时也同步。
- 首次请求完成前，用手机本地时间构造等效墙钟：
  - `epoch = Date.now()/1000`，`offsetMinutes = -new Date().getTimezoneOffset()`。
- `/api/time` 失败时继续使用上一次基准（或手机回退），不报错、不阻塞时钟。
- 同步后如果当前正停留在「当月」，把 `viewYear/viewMonth` 跟随新的 Mac 当前月；如果用户正在浏览他月，保留浏览位置。
- 跨日/跨月由现有的 5 秒检查处理，但判断依据改为 Mac 墙钟。

## 4. 时钟绘制

- `drawDial` 改为读取 UTC getter，因为传入的是墙钟 `Date`。
- 平滑秒针继续用毫秒累计；不引入新的定时器。
- 尺寸切换、全屏切换、回到前台时都用 `macWall()` 重绘。

## 5. 已知限制

- Mac 休眠、服务不可达时只能退回手机本地时间，此时仍可能不一致。
- 时区规则变化（如夏令时切换）最多滞后一个同步周期（10 分钟），对桌面副屏可接受。
- 天气「今天/明天」以 Mac 墙钟日期比较；若所选城市与 Mac 不在同一时区，日期边界可能相差一天，这是和风返回城市本地日期的既有语义。
