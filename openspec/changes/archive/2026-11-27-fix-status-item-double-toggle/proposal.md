# 提案：修复状态栏日历首次点击无响应、再次点击带出设置

## Why

状态栏每个条目同时接了两套点击：

1. `StatusBarCellView.mouseDown` 直接调用 `activateEntry()`；
2. 底层 `NSStatusBarButton` 在 `.leftMouseUp` 又调用一次。

日历使用非模态 `NSPopover`，一次点击被拆成「mouseDown 打开」+「mouseUp 关闭」，所以第一下看起来没反应。
第二下 popover 留下时，`NSApp.activate` 又把已有设置窗口当成 App 的 key window 带到最前，
表现为「点日历却把设置页也弹出来」。

## What Changes

- `StatusBarCellView` 不再接管 `mouseDown`，`hitTest` 返回 nil，让点击统一落到 `NSStatusBarButton` 的 action，一次点击只触发一次。
- `CalendarStatusBarEntry.activate` 改为：先 `popover.show` → popover 窗口 `makeKey` → 再 `NSApp.activate`。
  这样激活 App 时 key window 是日历 popover，设置窗口不会被一起带到最前。
- 不改变状态栏条目注册、菜单类条目（CPU/MEM/网速）行为。

**非目标**：

- 不改 popover 尺寸、内容与暗色外观。
- 不改设置窗口的显示逻辑。
- 不做新的状态栏功能。

## Capabilities

### Modified Capabilities

- `status-bar`：状态项单击只触发一次，日历 popover 不会被设置窗口抢前台。

## Impact

- 代码：`Core/StatusBar/StatusBarRegistry.swift`、`Modules/Calendar/CalendarStatusBarEntry.swift`。
- 数据/权限/入口：无变化。
