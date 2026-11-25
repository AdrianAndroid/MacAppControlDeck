# Change: 状态栏条目拆成独立状态项

## Why

`add-statusbar-registry` 把同组条目合并成一条 `NSStatusItem`，靠分段命中判断点到了哪一格。实际用起来三个指标挤在一个胶囊里：看不清哪个数字属于哪个指标，点哪一格还要靠坐标猜，菜单也只能贴着那条状态项弹。既然 CPU / MEM / 网速是三个独立信息，就应该各占一条状态项、各弹自己的菜单。

## What Changes

1. `StatusBarRegistry`：`StatusBarGroupControl`（一组一条状态项）改为 `StatusBarItemControl`（一条状态项一个条目），按 `order` 顺序创建；条目消失时拆掉自己的状态项，其余不重建。
2. 每条状态项独立 `autosaveName = MacAppControlDeck.status.<entryID>`，⌘-拖动的位置各自持久化；沿用 `NSStatusItem.variableLength` + 内容 0 内缩、不写死 `length`，状态项收到内容宽度，三条才挨得紧（写成固定 length 会为每项多留一圈空白）。
3. 点击不再做分段命中：`NSStatusBarButton.action` 直接转发给唯一格子，`entry.activate(from:)` 弹自己的菜单。
4. CPU 条目：`ProcessResourceMonitor.sampleCPUTop(limit:)`（同一采样器先打基线、隔 400ms 再采一次做差分），菜单列出 CPU 占用最高的 8 个应用 + 「打开 PureMac…」。
5. 网速条目：菜单列出 ↑ 上传 / ↓ 下载当前速率 + 「打开 PureMac…」；MEM 条目沿用现有内存排行菜单。
6. 设置 →「状态栏」文案改为「每个条目都是独立状态项」；`groupID` 只保留用于设置页归类。
7. 视觉统一：CPU / MEM 标签行由 `secondaryLabelColor` 改为 `labelColor`，与数值行、网速项保持同色；CPU / MEM 列按 `100%` 定宽，避免百分比位数变化时状态项宽度抖动。

## Capabilities

- `status-bar`（修改）：条目渲染单位由「组」改为「条目」，点击与菜单位置随之改变。
- `system-cleaner`（修改）：三个菜单栏条目的点击行为（CPU / 网速从开窗口改为弹菜单）。

## Impact

- `Core/StatusBar/StatusBarRegistry.swift`：分组控件替换为单条目控件，新增 `isBuilt` 复用逻辑。
- `Modules/SystemTool/SystemToolStatusEntries.swift`：三个条目各自实现 `activate(from:)`。
- 新增 `Modules/SystemTool/SystemToolStatusMenus.swift`（CPU / 网速菜单构建）。
- `UpstreamPureMac/ProcessResourceMonitor.swift`：新增一次性 `sampleCPUTop(limit:)`（只读 libproc，无权限申请）。
- 条目的 `statusbar.*` 勾选键不变；但旧的分组状态项位置不会迁移，需要 ⌘-拖动重排一次。

## Non-goals

- 不改主图标（应用控制台菜单）与模块菜单内容。
- 不做拖拽排序 UI、不做图标主题、不给状态项加右键菜单。
