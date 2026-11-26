# 提案：副屏视口外边框（UI 走查用）

## Why

副屏页面锁定在视口内、四边留白由 `--u` 算出，肉眼很难判断"内容有没有贴边 / 有没有溢出"。
UI 走查需要一个贴住视口四边的 1px 框，能一眼看出安全边距是否被吃掉。

## What Changes

- `#frame` 新增 `::after` 覆盖层：`inset: 0` + `inset box-shadow` 画 1px 亮青色描边。
- 不用 `border` / `outline`，**不占任何 margin / padding、不改变布局**，`pointer-events: none` 不吃点击。
- 新增设置：副屏设置页「外观」卡片增加「视口外边框（走查）」，**默认关闭**。
- 复用现有 `/api/screen/frame` 下发，新增 `viewportBorder` 字段。
- `ScreenHTML.version` 提升到 `2026-11-27.7`。

**非目标**：

- 不做网格线、标尺、坐标标注。
- 不影响现有「横屏模块边框」开关与强度。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：外观设置新增视口外边框开关。

## Impact

- 代码：`Panel/Screen/index.html`（CSS / `applyScreenFrame`）、
  `Modules/RemoteControl/ScreenAppearance.swift`、`UI/ScreenSettingsView.swift`、
  `Panel/ScreenHTML.swift`（版本号）。
- 权限/数据：无；开关存 `UserDefaults`，键 `screen.frame.viewportBorder`。
- 入口：走查开关位于设置 → 副屏 → 外观，不新增独立功能入口。
