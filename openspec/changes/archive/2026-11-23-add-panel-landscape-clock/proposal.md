# 提案：手机面板横屏增加系统时钟

## Why

手机在横屏时常被当作常驻控制台使用（放在桌面支架或边上），但面板目前只有「应用 / 快捷操作」两组按钮，没有任何时间信息。用户需要一眼看到当前的年月日、时分秒和星期，而不必退出面板去看手机状态栏。

横屏的空间刚好在标题栏右侧有富余，竖屏则空间紧张，因此只在横屏展示时钟。

## What Changes

- 手机面板标题栏新增系统时钟，仅在横屏显示：`YYYY年MM月DD日 星期X HH:mm:ss`。
- 时钟每秒刷新一次，使用设备本地时间；数字使用等宽数字，避免每秒宽度跳动。
- 竖屏不显示时钟，保持现有标题「Mac 应用快捷控制台 + 连接状态」布局不变。
- 更新 `PanelHTML.version`，让已打开的面板通过 `/api/panel-version` 自动刷新到新版本。

**非目标**：

- 不做闹钟、倒计时、时区切换或时间格式设置。
- 不读取 Mac 端时间，全部使用手机本地时间。
- 不改按钮数据模型、`/api/buttons`、`/api/activate` 协议。
- 不新增用户可见模块或窗口；沿用电脑控制模块现有入口，因此不需要新增内置打开按钮。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：新增「横屏系统时钟」要求，规定横屏显示年月日时分秒与星期、每秒刷新、竖屏隐藏。

## Impact

- 代码：`Sources/MacAppControlDeck/Panel/PanelHTML.swift`（标题栏元素、内联 CSS/JS 与版本号）。
- 规范：`openspec/specs/remote-web-panel/spec.md` 在归档时同步。
- 测试：多尺寸横屏/竖屏手测与本地 mock 面板截图；`swift build -c release`、`./Build/build.sh`、`./Build/verify-signing.sh`。
- 权限/API/数据：无新增权限、无接口变更、无数据迁移。
