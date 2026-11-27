# 设计：修复状态栏日历首次点击无响应、再次点击带出设置

## 根因

### 1. 一次点击触发两次

```swift
// StatusBarCellView（修复前）
override func mouseDown(with event: NSEvent) {
    activateEntry()
}

// StatusBarItemControl
button.action = #selector(statusButtonClicked)
button.sendAction(on: [.leftMouseUp])
```

日历 `activate()` 是非模态的：mouseDown 创建并显示 popover，紧接着 mouseUp 的 button action 又看到
`popover.isShown == true`，执行 `performClose`。所以第一下"没反应"。

菜单类条目因为 `NSMenu.popUp` 在 mouseDown 内进入模态循环，mouseUp 被菜单吃掉，才没有暴露这个问题。

### 2. 设置窗口被激活带前

修复前顺序是 `NSApp.activate` → `popover.show`。激活时设置窗口仍是 App 的 key window，
会被系统带到最前；随后 popover 才出现，看起来像"日历和设置一起弹出来"。

## 修复

```swift
// StatusBarCellView
override func hitTest(_ point: NSPoint) -> NSView? { nil }
```

- 点击事件直接落到 `NSStatusBarButton`，只在 `.leftMouseUp` 调一次 `activateEntry()`。
- 子视图（图标/文字）不再拦截鼠标。

```swift
panel.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
if let window = panel.contentViewController?.view.window {
    window.makeKey()
}
NSApp.activate(ignoringOtherApps: true)
```

- 先显示并让 popover 成为 key window，再激活 App；设置窗口不再被当作要带到最前的窗口。
- 仍然是 transient popover：点击外部会关闭，和其他菜单栏 popover 一致。

## 验证

- 日历图标第一次点击即弹出月历。
- 再次点击关闭；不会自动把设置窗口带到前面。
- CPU/MEM/网速等菜单类条目仍单击打开一次、点击外部关闭。
- `swift build` 通过；安装后验证。
