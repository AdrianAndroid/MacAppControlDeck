# 提案：状态栏增加「区域截图」快捷图标

## Why

区域截图目前藏在菜单栏「截图与录屏 → 区域截图」与全局快捷键（默认关闭）里。用户希望状态栏常驻一个截图图标，点一下直接进入框选，不需要再展开菜单。

## What Changes

- 新增状态栏条目 `capture.region`：`rectangle.dashed` 图标，归属 `capture` 模块，`order = 4`，首次安装默认显示。
- 点击状态项直接调用 `MacShotController.shared.captureArea()`，不弹菜单、不开窗口。
- 条目进入公共状态栏层：设置 → 状态栏 可按模块开关；关闭「截图与录屏」模块时图标自动移除，重新启用后按原勾选恢复。
- 快捷入口复用已有内置操作 `capture.area`（「截图（区域）」），不新增第二套按钮。

**非目标**：

- 不改截图覆盖层、标注编辑器与录屏行为。
- 不为截图新增全局快捷键。
- 不增加右键菜单或其他子项。

## Capabilities

### Modified Capabilities

- `status-bar`：新增区域截图状态项。

## Impact

- 代码：新增 `Modules/Capture/CaptureStatusBarEntry.swift`，`CaptureModule.start()` 注册条目。
- 数据：仅复用 `statusbar.capture.region` 开关，无新增文件或权限。
- 权限：沿用屏幕录制授权；未授权时仍走原有 `captureArea()` 提示流程。

## 非目标补充

- 无新增独立模块，R0 的内置快捷入口由既有 `capture.area` 承担；状态图标本身也是直达入口。
