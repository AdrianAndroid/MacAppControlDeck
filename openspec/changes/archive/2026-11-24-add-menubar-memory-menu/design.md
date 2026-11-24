# Design: MEM 菜单栏内存占用下拉菜单

## 1. 目标

点击 MEM 独立状态项弹出柠檬式内存占用菜单：百分比标题 + 应用内存排行 + 每行「关闭」按钮 +
底部安全提示。不打开主窗口；CPU / 网速项点击行为不变。

## 2. 数据来源

复用 `UpstreamPureMac/ProcessResourceMonitor.swift`：
- `ProcessResourceSampler.sample()` 已有 `proc_pidinfo(PROC_PIDTASKALLINFO)` 读每个进程
  `residentBytes`、按 `.app` 归组 helper、过滤受保护进程，零权限。
- 现有 `ProcessResourceMonitor` 是 `@MainActor ObservableObject` + 常驻 2s 采样（供进程页用）。
  菜单栏菜单**不复用它的常驻任务**，而是新增一个一次性 API：在点击时 `await` 采样一次，
  取 `ProcessResourceMath.sorted(..., by: .memory)` 前 N 项。避免与主窗口进程页互相干扰。

## 3. 菜单构建（AppKit NSMenu）

- 给 MEM 的 `NSStatusBarButton` 设置 `menu`，并保留 `action` 用于点击时即时刷新数据。
  - 采用 `NSMenuDelegate.menuWillOpen` 在弹出前同步刷新菜单项（数据已在点击 action 里异步取好缓存），
    这样点击即可见最新数据，且不阻塞主线程做 libproc 遍历。
  - 简化实现：点击 MEM → `Task { @MainActor in 采样; 构建 menu; button.menu = menu; 弹出 }`。
- 菜单结构：
  1. 标题项 `内存占用 XX%`（禁用，粗体）。
  2. 分隔线。
  3. 每个应用一项：自定义 `NSMenuItem.view`（`NSView`）：左图标 + 名称 + 右占用大小 + 「关闭」按钮。
     按 `residentBytes` 降序，取前 8~10 项。
  4. 分隔线 + 底部提示项 `关闭将直接退出程序，请先保存重要数据`（禁用，小字）。
- 图标：`NSWorkspace.shared.icon(forFile: applicationPath)`。

## 4. 关闭应用的安全策略

复用进程页 `ProcessViews` 的既有规则（提取为共享工具，避免两处漂移）：
- `applicationPath` 必须以 `/Applications` 开头或包含 `/Applications/`，或以 `NSHomeDirectory()` 开头；
  否则禁用「关闭」（系统 / root / 受保护进程）。
- 通过 `NSWorkspace.shared.runningApplications` 按 `bundleURL.path` 找到 `NSRunningApplication`，
  调 `terminate()`（普通退出；不提供 force，避免误杀未保存数据）。
- 退出后从菜单移除该项并刷新剩余菜单。

## 5. 关键决策

- **不常驻采样**：点击才采样一次，避免额外 CPU 开销（进程页的常驻采样仍只在打开进程页时运行）。
- **普通退出而非强制**：符合提示语「请先保存重要数据」，不做 forceTerminate。
- **安全规则单一来源**：把 `canTerminate` 提取为共享函数，菜单与进程页共用。
- **仅 MEM 项改点击行为**：CPU / 网速保持点击打开主窗口，避免用户预期混乱。

## 6. 验收

- 点击 MEM 弹出菜单，顶部百分比与状态项一致；列表按内存降序，图标 / 名称 / 大小正确。
- 用户应用行「关闭」可点击并真实退出；系统 / root 进程行「关闭」禁用。
- 菜单数据为点击即时采样；重复打开数据刷新。
- `swift build` / 全量测试通过；release 覆盖安装截图验收。
