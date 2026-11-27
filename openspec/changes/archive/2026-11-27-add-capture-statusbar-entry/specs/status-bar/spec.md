# status-bar 变更（add-capture-statusbar-entry）

## MODIFIED Requirements

### Requirement: 条目注册与独立渲染

模块 SHALL 通过 `StatusBarEntry` 注册条目；每个条目 MUST 渲染成独立的 `NSStatusItem`（一条状态项只承载一个条目），状态栏先后由 `order` 决定，不随启动顺序变化。`groupID` 仅用于设置页归类。当前条目共五条：CPU / MEM / 网速 / 日历 / 区域截图。

#### Scenario: 五条条目
- **WHEN** 全部模块启用且五个条目都可见
- **THEN** 状态栏出现五条独立状态项，彼此紧邻（每条只占内容宽度）
- **AND** 三条监控项各显示自己的数值，日历与区域截图各显示一个固定宽度的图标

#### Scenario: 点击各自菜单
- **WHEN** 点击任意一条状态项
- **THEN** 只触发该条目的动作
- **AND** CPU 弹「占用最高的应用 + 打开 PureMac…」，MEM 弹内存排行，网速弹 ↑/↓ 速率菜单，日历弹月历浮层，区域截图直接进入框选

## ADDED Requirements

### Requirement: 区域截图状态项

截图与录屏模块启用时 SHALL 注册 `capture.region` 条目：状态栏显示 `rectangle.dashed` 图标，点击一次直接进入区域截图，不弹菜单、不打开独立窗口。

#### Scenario: 点击截图
- **WHEN** 用户点击状态栏的截图图标
- **THEN** 立即调用区域截图流程，出现选区覆盖层
- **AND** 不需要先展开「截图与录屏」菜单

#### Scenario: 开关与联动
- **WHEN** 在 设置 → 状态栏 关闭该条目，或关闭「截图与录屏」模块
- **THEN** 图标立即从状态栏移除；模块重新启用后按原勾选恢复
- **AND** 关闭该图标不影响菜单栏「截图与录屏」里的区域截图入口与 `F1` 快捷键
