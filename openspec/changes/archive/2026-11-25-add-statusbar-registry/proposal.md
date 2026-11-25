# Change: 状态栏抽成公共层，条目按模块注册

## Why

PureMac 在 `NSStatusBar` 里自建三个独立状态项：每次启动顺序可能不同；开关散落在各模块设置里；后续还要加「点击不同图标弹不同菜单/开不同窗口」，继续让模块直接操作状态栏会越写越乱。

## What Changes

1. 新增公共层 `Core/StatusBar`：`StatusBarEntry` 协议、`StatusBarStore`（每条目开关 + 旧键迁移）、`StatusBarRegistry`（分组、顺序、重建）与 `StatusBarMetricView`（两行指标视图）。
2. 一个 group 只建一个 `NSStatusItem`，组内每格独立可点、由条目自己决定弹菜单或打开窗口；组内顺序由 `order` 固定。
3. PureMac 三个监控改为注册 `systemTool.cpu / mem / net` 条目；CPU 点开 PureMac，MEM 弹内存排行菜单，网速点开 PureMac。
4. 设置新增「状态栏」Tab：按模块分组列出全部条目；模块关闭时开关置灰但保留勾选，状态栏同步移除；PureMac 自身设置页的三个卡片改为绑定同一份公共数据。
5. 旧偏好 `systemTool.menubar.showCPU/showMEM/showNetSpeed` 自动迁移到 `statusbar.systemTool.*`。
6. 主图标保持独立状态项（带 `autosaveName`，可用 ⌘-拖动固定位置）；程序不尝试对其排序。

## Capabilities

- `status-bar`（新增）：状态栏条目的注册、分组、开关与模块联动。
- `system-cleaner`（修改）：菜单栏监控由模块自建改为注册公共条目。

## Impact

- 新增 `Core/StatusBar/*` 4 个文件、`Modules/SystemTool/SystemToolStatusEntries.swift`、`UI/StatusBarSettingsView.swift`。
- 删掉 `SystemToolModule` 内自建状态项与 `statusCancellables`；`SystemToolSettingsView` 改绑公共层。
- 主图标（应用控制台菜单）完全不改。
- 无新增权限；接口/副屏不受影响。

## Non-goals

- 不改各模块自己的菜单内容；不做拖拽排序；不做状态栏图标自定义主题。
