# Tasks

- [x] 建变更记录、设计与能力 delta
- [x] `OffWorkCountdown.swift`：配置单例 + `snapshot(now:config:)` 纯函数 + 快照 Codable
- [x] `APIRouter` 新增 `GET /api/screen/countdown`
- [x] `ScreenHTML`：月历行高封顶（随 `--u`）+ 倒计时卡 HTML/CSS
- [x] `ScreenHTML` JS：拉配置、秒对齐倒数、到点重取、四档降级（ResizeObserver）
- [x] 三套内联 SVG 动效 + reduced-motion 冻结
- [x] `ScreenSettingsView` 新增设置卡（开关/时间/显示秒/竖屏/预览）+ 事件推送
- [x] `OffWorkCountdownTests`（三态、跨夜班、进度、文案、边界 23:59:59）
- [x] `APIRouterTests` 增加 countdown 接口断言
- [x] 构建 + 固定签名覆盖安装
- [x] 五视口截图验收（480×320 / 844×390 / 1440×900 / 500×900 / 320×568），存 `Docs/verification/screen-countdown/`
- [x] 同步 README 与 `openspec/specs/remote-web-panel/spec.md`，归档变更

## Verification

- `swift test --filter OffWorkCountdownTests`：7 项全绿
- `swift test --filter APIRouterTests`：15 项全绿（含新增 `/api/screen/countdown`）
- 头less Chrome 截图：844×390 / 480×320 / 1440×900 均为 full 档、无页面溢出；500×900 竖屏默认 hidden；已下班状态绿色正计时
- 截图见 `Docs/verification/screen-countdown/`
