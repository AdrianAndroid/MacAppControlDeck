# status-bar Specification

## Purpose

定义状态栏的公共注册层：模块只声明条目，公共层负责独立渲染（一条状态项一个条目）、固定顺序、开关持久化与模块联动。

## Requirements

### Requirement: 条目注册与独立渲染

模块 SHALL 通过 `StatusBarEntry` 注册条目；每个条目 MUST 渲染成独立的 `NSStatusItem`（一条状态项只承载一个条目），状态栏先后由 `order` 决定，不随启动顺序变化。`groupID` 仅用于设置页归类。

#### Scenario: 三条条目
- **WHEN** PureMac 注册 CPU / MEM / 网速三个条目且都可见
- **THEN** 状态栏出现三条独立状态项，彼此紧邻（每条只占内容宽度）
- **AND** 每条状态项只显示自己的数值，不与其他条目合并在一个胶囊里

#### Scenario: 点击各自菜单
- **WHEN** 点击任意一条状态项
- **THEN** 只触发该条目的动作，菜单弹在这条状态项正下方
- **AND** CPU 弹「占用最高的应用 + 打开 PureMac…」，MEM 弹内存排行，网速弹 ↑/↓ 速率菜单

#### Scenario: 全部关闭
- **WHEN** 三个条目全部关闭或模块被禁用
- **THEN** 三条状态项全部消失，不残留空壳

#### Scenario: 位置持久化
- **WHEN** 用户 ⌘-拖动调整其中一条状态项的位置
- **THEN** 重启后三条的相对顺序保持（每条状态项独立 `autosaveName`）

### Requirement: 状态项不复用分段命中

一条状态项只承载一个条目时，MUST 由 `NSStatusBarButton` 的 action 直接转发给该条目，不得再按坐标做分段命中。

#### Scenario: 按钮转发
- **WHEN** 用户在状态项上按下并抬起左键
- **THEN** 直接调用该条目的 `activate(from:)`，命中判断只可能是这一个条目

### Requirement: 开关与模块联动

条目的可见性 SHALL 由「模块启用」与「用户勾选」共同决定；模块关闭时设置页开关置灰、勾选保留、状态栏移除，重新启用后按勾选恢复。

#### Scenario: 模块关闭
- **WHEN** 用户在 设置 → 模块 关闭 PureMac
- **THEN** 状态栏三格立即消失
- **AND** 设置 → 状态栏 中三项变灰不可点，勾选状态保留

#### Scenario: 旧偏好迁移
- **WHEN** 从旧版本升级
- **THEN** `systemTool.menubar.showCPU/showMEM/showNetSpeed` 自动迁移到 `statusbar.systemTool.*`，首次渲染与升级前一致

### Requirement: 主图标不受影响

应用控制台主菜单图标 SHALL 保持独立状态项，不参与分组，也不受条目开关影响。
