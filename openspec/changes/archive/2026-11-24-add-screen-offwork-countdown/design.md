# Design: 副屏下班倒计时

## 1. 谁来算时间

页面已有「Mac 墙钟」逻辑（`/api/time` 把 Mac 的 epoch 与 offset 平移到本地 getter）。倒计时如果也在页面算，就要复刻「跨夜班、已下班正计时、24:00 归位」规则，容易与 Swift 侧漂移。

因此：**Swift 计算阶段与目标时间点，页面只做 `targetEpoch - now` 的差值显示**，差值 ≤ 0 时重新请求一次配置。Swift 侧是可单测的纯函数：

```swift
struct OffWorkSnapshot { phase, label, targetEpoch, targetText, progress, countUp }
func snapshot(now: Date, config: OffWorkConfig, calendar: Calendar) -> OffWorkSnapshot
```

## 2. 阶段规则（每天一致，不区分工作日）

| 条件 | phase | 文案 | 数字 |
| --- | --- | --- | --- |
| 跨夜班（end ≤ start） | | | |
| now ≥ start 或 now < end | working | 距下班 | 到 end（次日） |
| 其余（end ≤ now < start） | before | 距上班 | 到 start |
| 普通（end > start） | | | |
| now < start | before | 距上班 | 到 start |
| start ≤ now < end | working | 距下班 | 到 end |
| now ≥ end | after | 已下班 | 从 start 正计时 |

`progress = (now - start) / (end - start)`，只在 working 使用，钳到 0…1。

## 3. 接口

```
GET /api/screen/countdown
{
  "enabled": true,
  "phase": "working",
  "label": "距下班",
  "targetEpoch": 1795500000.0,
  "targetText": "18:30 下班",
  "progress": 0.52,
  "countUp": false,
  "showSeconds": true,
  "portrait": false,
  "serverEpoch": 1795519200.0
}
```

免配对、只读，与 `/api/time`、`/api/weather` 同级；`Cache-Control: no-store`。

## 4. 布局与四档降级

月历与倒计时放进 `.cal-group`，整体垂直居中，两者固定间距 1.8u；月历行高上限 `max(25u, 36vh)`，上下留白 2.1u / 0.5u。倒计时卡是有底色的圆角面板（`rgba(255,255,255,.045)` + 1px 边框），左侧 6.4u 动态图标、中间「标签 / 数字 / 目标行」、右侧进度环（conic 用 SVG dasharray，工作态显示百分比）。

再用 `ResizeObserver` 按月历栏宽高写 `#cd[data-tier]`（宽度和高度两个维度都要够，避免极窄横屏溢出）：

| tier | 条件（px，随 --u 缩放） | 内容 |
| --- | --- | --- |
| full | ≥ 5.4u×2 + 1.2u | 图标 + 两行文字（标签、数字、目标行） |
| slim | ≥ 4.2u + 1.0u | 图标 + 两行（标签、数字） |
| line | ≥ 2.6u | 图标与数字同排单行 |
| hidden | 不足或竖屏未开启 | 不渲染 |

## 5. 秒对齐与防抖

- `setTimeout(1000 - Date.now() % 1000)` 对齐系统秒边界；
- 数字 `font-variant-numeric: tabular-nums; min-width: 8ch`；
- 差值 ≤ 0 → `refresh()` 重新拉接口（同时兼容 Mac 时间跳变/休眠唤醒）。

## 6. 动效

内联 SVG + CSS `@keyframes`，三组：
- working：屏幕亮度呼吸（1.6s）+ 光标闪烁（1s）；
- before：热气上浮 3 帧（2.4s）；
- after：小人左右移动 3 帧（1.05s）。

`@media (prefers-reduced-motion: reduce)` 全部 `animation: none`。

## 7. 设置

`OffWorkSettings` 单例（UserDefaults `screen.offwork.*`），改动后 `ScreenEventHub.notifyChange()`；设置页用 `DatePicker(.hourAndMinute)` 绑定到「距 0 点分钟数」，避免 Date 时区问题。
