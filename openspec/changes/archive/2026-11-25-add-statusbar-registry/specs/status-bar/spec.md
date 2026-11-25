# status-bar Specification

## Purpose

定义状态栏的公共注册层：模块只声明条目，公共层负责分组渲染、固定顺序、开关持久化与模块联动。

## Requirements

### Requirement: 条目注册与分组渲染

模块 SHALL 通过 `StatusBarEntry` 注册条目；同一 `groupID` 的条目 MUST 渲染在同一个 `NSStatusItem` 内，顺序由 `order` 决定，不随启动顺序变化。

#### Scenario: 同组多条目
- **WHEN** PureMac 注册 CPU / MEM / 网速三个条目
- **THEN** 状态栏只出现一条状态项，内部三格按 CPU → MEM → 网速 排列
- **AND** 每格可独立点击，触发各自的菜单或窗口

#### Scenario: 组内全部关闭
- **WHEN** 三个条目全部关闭或模块被禁用
- **THEN** 该组状态项整体消失，不残留空壳

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
