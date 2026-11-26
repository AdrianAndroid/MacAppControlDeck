# Change: 副屏宠物按真实数据状态化（含性能基线）

## Why

副屏左下角的宠物卡片只有 cat / dog / robot 三只两帧腿部动画 + 左右横移，看久了单调；同时页面长期常亮在手机浏览器上，现有实现里有两个 60fps rAF 循环、每帧强制布局、每 280ms 重建 SVG、15fps 全量重绘 canvas，属于会累积发热与掉帧的写法。

## What Changes

1. **性能基线（先行）**：合并成单一 rAF（宠物 30fps、时钟 1fps 仅在秒变化时重绘）；宠物尺寸只在布局变化时测量，每帧零 DOM 读取；肢体与道具常驻 DOM，只切 `data-frame` / `data-state`，不再 `innerHTML` 重建 SVG。
2. **状态机**：按优先级判定 `celebrate > packup > sleep > rain > cold > hot > idle`，数据来自已有的 `/api/time`、`/api/weather`、`/api/screen/countdown`，不新增请求。休息日按周末判定（页面拿不到法定节假日）。
3. **道具层**：Zzz、伞 + 雨滴、围巾、汗滴、手表、四角星，全部 CSS `transform` / `opacity` 动画，每只宠物只提供三个锚点（头顶 / 右上 / 颈 / 身侧）。
4. **文案**：非 idle 时在宠物名后追加状态短语（「打伞 / 睡了 / 还有 N 分钟下班 / 已下班 …」）。
5. **配置**：`petLive`（默认 `true`）→ 设置 → 副屏「宠物随环境变化（时间 / 天气 / 下班）」，关闭后行为与旧版一致。
6. 页面增加只读 QA 参数 `?petState=`，仅用于本地截图核对。

## Capabilities

- `remote-web-panel`（修改）：副屏宠物卡片的状态、道具与性能约束。

## Impact

- `Panel/Screen/index.html`（宠物段落重写 + CSS）、`ScreenHTML.version`、`ScreenDisplaySettings.swift`、`ScreenSettingsView.swift`、`APIRouter.swift`（已带正确版本时不再 302，保留附加查询参数）。
- 不动 Mac 桌面桌宠（`Modules/Pet`）、`/api/*` 契约与第三方素材。

## Non-goals

- 不做任何互动（点击 / 拖拽 / 语音），副屏保持只读。
- 不新增宠物（水豚等留待下一轮）、不做多宠物同屏。
