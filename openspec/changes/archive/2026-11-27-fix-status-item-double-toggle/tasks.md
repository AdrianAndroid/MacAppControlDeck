# 任务：修复状态栏日历首次点击无响应、再次点击带出设置

## 1. 修复

- [x] 1.1 `StatusBarCellView.hitTest` 返回 nil，移除 mouseDown 二次触发
- [x] 1.2 点击统一由 `NSStatusBarButton` 的 `.leftMouseUp` action 处理
- [x] 1.3 日历 popover 先 show + makeKey，再 `NSApp.activate`

## 2. 验证

- [x] 2.1 `swift build` 通过
- [x] 2.2 状态栏单次点击只触发一次 activateEntry（代码路径）
- [x] 2.3 日历 popover 关闭逻辑保留（再次点击/点外部关闭）
- [x] 2.4 覆盖安装后由用户复核点击行为
