# 设计：一条状态项一个条目

## 1. 渲染单位

```
改前（分组）                          改后（独立）
┌───────────────────────┐            ┌──────┐ ┌──────┐ ┌────────┐
│ ┌───┐┌───┐┌───┐       │            │ 31%  │ │ 54%  │ │ ↑ ..   │
│ │31%││54%││↑↓ │       │            │ CPU  │ │ MEM  │ │ ↓ ..   │
│ └───┘└───┘└───┘       │            └──────┘ └──────┘ └────────┘
└───────────────────────┘              点击各自弹各自菜单
  点哪一格靠坐标命中
```

- 注册中心仍按 `groupID` 生成设置页快照，但**不再**用它决定状态项数量
- `entries.filter(isAvailable && isVisible).sorted(by: order)` → 每个条目一条 `NSStatusItem`
- 已建好的条目直接复用（`isBuilt`），避免每次 `reload()` 重建引起闪烁；只有新出现的条目才新建，消失的才 `teardown()`

## 2. 点击

分组方案里 `NSStatusBarButton` 会吞掉子视图的 `mouseDown`，所以只能给按钮装 action 再做一次分段命中：

```swift
let hit = cells.first { $0.convert($0.bounds, to: sender).contains(location) }
hit?.activateEntry()
```

一条状态项只剩一格后，这段命中逻辑没有任何意义，直接：

```swift
button.target = self
button.action = #selector(statusButtonClicked)   // → cell.activateEntry()
button.sendAction(on: [.leftMouseUp])
```

`entry.activate(from: cell)` 仍然拿到一个真实视图，用来给菜单定位（`menu.popUp(at: NSPoint(x: 0, y: view.bounds.height), in: view)`，弹在状态项正下方）。

## 3. 位置

每条状态项使用自己的 `autosaveName`：

```swift
item.autosaveName = "MacAppControlDeck.status.\(entry.id)"
```

旧的分组项用的是 `MacAppControlDeck.group.<groupID>`，升级后不会继承旧位置——三条会按创建顺序出现在默认位置，用户 ⌘-拖动一次即可，之后重启保持不变。

## 3.1 为什么第一版拆开后"散"了

拆分后第一版给每条状态项显式赋了 `item.length = 内容宽 + 12`，格子还留了 6pt 左右内缩。`length` 是状态项**整格**宽度，多出来的部分就变成每一项左右各一圈空白，三条之间看着像隔了很远。

最初的 PureMac（v0.4.1）用的是 `NSStatusItem.variableLength` + 把内容视图紧贴按钮边缘（0 内缩），状态项自己收到内容宽度，因此看起来紧挨着。

所以现在回到同样的写法：

```swift
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
cell.leadingAnchor.constraint(equalTo: button.leadingAnchor)      // 0 内缩
cell.trailingAnchor.constraint(equalTo: button.trailingAnchor)
// 不赋 item.length
```

差别只是给每条状态项加了独立的 `autosaveName`，⌘-拖动位置仍能持久化。三条之间剩下的是系统自己的窄间距，视觉上已经是一条「组」；点哪条仍然弹哪条自己的菜单。

## 4. CPU 菜单为什么要两次采样

`ProcessResourceMath.cpuFraction` 需要「当前读数 − 上一次读数」才能算占用，一次采样只能拿到 nil。所以 `sampleCPUTop` 在同一个 `ProcessResourceSampler` 上先采一次基线，`Task.sleep(400ms)` 后再采一次，第二次的差分才有值；这段采样完全在后台 actor 上跑，不阻塞主线程，也不常驻。

## 5. 菜单构成

| 条目 | 标题 | 内容 | 末尾 |
| --- | --- | --- | --- |
| CPU | `CPU 占用 NN%` | 占用最高的 8 个应用（图标 + 名称 + 占比） | 打开 PureMac… |
| MEM | `内存占用 NN%` | 沿用现有内存排行（带「关闭」按钮） | 关闭风险提示 |
| 网速 | `实时网速` | ↑ 上传 / ↓ 下载当前速率 | 打开 PureMac… |

菜单位置与关闭语义不变；CPU / 网速不再靠点开主窗口才能看明细。

## 6. 放弃的方案

- **保留分组但加分隔线**：解决不了「点哪一格靠坐标猜」，且菜单仍只能挂在整条状态项上。
- **一条状态项 + 每个条目自带 popover**：状态栏按钮仍然吞事件，需要更复杂的转发布局，收益不如直接拆开。
