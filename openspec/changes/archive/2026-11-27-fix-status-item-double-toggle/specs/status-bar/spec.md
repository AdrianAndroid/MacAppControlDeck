# status-bar 变更（fix-status-item-double-toggle）

## ADDED Requirements

### Requirement: 状态项单击只触发一次

每个状态栏条目 SHALL 对一次鼠标点击只调用一次 `activate`，不得同时由子视图 `mouseDown` 和按钮 action 各触发一次。

#### Scenario: 日历首次点击
- **WHEN** App 不在前台，用户第一次点击状态栏日历图标
- **THEN** 月历 popover 立即显示并保持打开
- **AND** 不会先打开再立即关闭

#### Scenario: 再次点击
- **WHEN** 日历 popover 已打开，用户再次点击日历图标
- **THEN** popover 关闭，行为与其他菜单栏 popover 一致

#### Scenario: 不抢设置窗口
- **WHEN** 设置窗口处于打开或后台状态，用户点击状态栏日历图标
- **THEN** 只显示日历 popover
- **AND** 设置窗口不会被激活带到最前

#### Scenario: 菜单类条目不受影响
- **WHEN** 用户点击 CPU / MEM / 网速条目
- **THEN** 对应菜单仍只打开一次，点击外部关闭
