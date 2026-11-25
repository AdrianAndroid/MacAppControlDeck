# status-bar Specification

## Purpose

定义状态栏的公共注册层：模块只声明条目，公共层负责独立渲染（一条状态项一个条目）、固定顺序、开关持久化与模块联动。

## Requirements

### Requirement: 条目注册与独立渲染

模块 SHALL 通过 `StatusBarEntry` 注册条目；每个条目 MUST 渲染成独立的 `NSStatusItem`（一条状态项只承载一个条目），状态栏先后由 `order` 决定，不随启动顺序变化。`groupID` 仅用于设置页归类。当前条目共四条：CPU / MEM / 网速 / 日历图标。

#### Scenario: 四条条目
- **WHEN** PureMac 注册 CPU / MEM / 网速 / 日历四个条目且都可见
- **THEN** 状态栏出现四条独立状态项，彼此紧邻（每条只占内容宽度）
- **AND** 三条监控项各显示自己的数值，日历项只显示一个固定宽度的日历图标，都不与其他条目合并在一个胶囊里

#### Scenario: 点击各自菜单
- **WHEN** 点击任意一条状态项
- **THEN** 只触发该条目的动作，菜单弹在这条状态项正下方
- **AND** CPU 弹「占用最高的应用 + 打开 PureMac…」，MEM 弹内存排行，网速弹 ↑/↓ 速率菜单，日历弹月历 `NSPopover`

#### Scenario: 全部关闭
- **WHEN** CPU / MEM / 网速三个条目全部关闭或 PureMac 模块被禁用
- **THEN** 三条监控状态项全部消失，不残留空壳
- **AND** 日历项由万年历模块独立控制，不受三条监控项开关影响

#### Scenario: 位置持久化
- **WHEN** 用户 ⌘-拖动调整其中一条状态项的位置
- **THEN** 重启后四条的相对顺序保持（每条状态项独立 `autosaveName`）

### Requirement: 状态项不复用分段命中

一条状态项只承载一个条目时，MUST 由 `NSStatusBarButton` 的 action 直接转发给该条目，不得再按坐标做分段命中。

#### Scenario: 按钮转发
- **WHEN** 用户在状态项上按下并抬起左键
- **THEN** 直接调用该条目的 `activate(from:)`，命中判断只可能是这一个条目

### Requirement: 开关与模块联动

条目的可见性 SHALL 由「模块启用」与「用户勾选」共同决定；模块关闭时设置页开关置灰、勾选保留、状态栏移除，重新启用后按勾选恢复。

#### Scenario: 模块关闭
- **WHEN** 用户在 设置 → 模块 关闭 PureMac
- **THEN** 状态栏三条监控项立即消失
- **AND** 设置 → 状态栏 中三条监控项变灰不可点，勾选状态保留
- **AND** 日历项由万年历模块单独联动，关闭万年历模块时立即消失并关闭已弹出的面板

#### Scenario: 旧偏好迁移
- **WHEN** 从旧版本升级
- **THEN** `systemTool.menubar.showCPU/showMEM/showNetSpeed` 自动迁移到 `statusbar.systemTool.*`，首次渲染与升级前一致

### Requirement: 主图标不受影响

应用控制台主菜单图标 SHALL 保持独立状态项，不参与分组，也不受条目开关影响。

### Requirement: 日历图标状态项与月历下拉

万年历模块启用时 SHALL 注册 `calendar.panel` 条目：状态栏只显示一个日历图标（SF Symbol `calendar`），不显示日期文字，宽度固定；点击弹 `NSPopover` 月历面板而不是 `NSMenu` 或独立窗口。

#### Scenario: 图标显示
- **WHEN** 万年历模块启用且日历条目可见
- **THEN** 状态栏出现第四条状态项，只有一个日历图标、无日期文字
- **AND** 图标在亮/暗模式下都清晰可见，宽度不随日期变化

#### Scenario: 深色玻璃月历卡片
- **WHEN** 面板打开
- **THEN** 显示 16pt 圆角深色毛玻璃卡片与 1px 亮边，顶部箭头指向状态项
- **AND** 头部显示大号「yyyy年M月」标题与 `‹ ○ ›` 控件，周日起始，邻月日期 30% 淡显

#### Scenario: 农历标记而非日程
- **WHEN** 面板渲染任意日期格
- **THEN** 显示公历数字、农历/节气小字、今日蓝色描边，以及由节日/节气/休班推导的彩色小圆点与书签
- **AND** 不读取 EventKit 日程、不申请日历权限、不展示用户私人事件

#### Scenario: 打开完整万年历
- **WHEN** 用户点击标题栏右侧 `⋯` 菜单并选择「打开完整万年历…」
- **THEN** 关闭 popover 并打开现有 `CalendarWindowView` 独立窗口
- **AND** 选择「设置…」跳到设置页万年历标签

#### Scenario: 关闭与联动
- **WHEN** 用户再次点击日历图标、点击面板外部，或关闭万年历模块
- **THEN** 面板关闭；模块关闭时状态项也立即消失
- **AND** 其余三条监控状态项不受影响
