# status-bar Delta

## MODIFIED Requirements

### Requirement: 条目注册与独立渲染

模块 SHALL 通过 `StatusBarEntry` 注册条目；每个条目 MUST 渲染成独立的 `NSStatusItem`（一条状态项只承载一个条目），状态栏先后由 `order` 决定，不随启动顺序变化。

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

## ADDED Requirements

### Requirement: 状态项不复用分段命中

一条状态项只承载一个条目时，MUST 由 `NSStatusBarButton` 的 action 直接转发给该条目，不得再按坐标做分段命中。

#### Scenario: 按钮转发
- **WHEN** 用户在状态项上按下并抬起左键
- **THEN** 直接调用该条目的 `activate(from:)`，命中判断只可能是这一个条目
