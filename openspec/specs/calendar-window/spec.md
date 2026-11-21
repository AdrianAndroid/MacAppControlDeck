# calendar-window 规格

## Purpose

约束万年历模块：保留现有菜单栏下拉交互，只在其中增加「万年历」入口；完整日历使用独立窗口；默认打开才加载、关闭窗口释放；核心模块保持常驻，日历可通过设置选择常驻或释放。

## Requirements

### Requirement: 菜单内的万年历入口

系统 SHALL 在现有菜单栏下拉菜单中新增「万年历」子菜单，且不改变点击状态栏图标弹出下拉菜单的现有行为。菜单 SHALL 包含今日摘要与「打开万年历…」动作。

#### Scenario: 打开下拉菜单

- **WHEN** 用户点击状态栏图标
- **THEN** 仍显示现有原生下拉菜单
- **AND** 菜单中出现「万年历」子菜单，不新增第二个状态栏图标

#### Scenario: 查看今日摘要

- **WHEN** 用户展开「万年历」子菜单
- **THEN** 显示今天公历、农历、宜忌摘要与下一个节假日倒计时
- **AND** 摘要项不可点击，只作为只读信息

#### Scenario: 打开完整日历

- **WHEN** 用户点击「打开万年历…」
- **THEN** 打开独立日历窗口
- **AND** 状态栏下拉菜单保持原样

### Requirement: 独立日历窗口

系统 SHALL 提供独立日历窗口，展示月历、农历、节气、节日、法定节假日角标、选中日期详情、宜忌和节假日倒计时。

#### Scenario: 月历展示

- **WHEN** 日历窗口打开
- **THEN** 显示当前月 7 列日期格
- **AND** 每格显示公历日、农历或节气/节日副标题
- **AND** 周末使用红色强调，今天使用描边强调

#### Scenario: 法定节假日

- **WHEN** 某日存在法定节假日或调休
- **THEN** 日期格显示 `休` 或 `班` 角标
- **AND** 底部详情显示下一个节假日倒计时

#### Scenario: 选择日期

- **WHEN** 用户点击任意日期
- **THEN** 底部详情切换为该日期的农历、干支、生肖、宜忌
- **AND** 点击其他月份日期时切换到对应月份

### Requirement: 懒加载与关闭释放

日历模块 SHALL 默认不常驻；只有打开窗口时才创建 runtime，关闭窗口后 SHALL 释放窗口、ViewStore 与日历数据。

#### Scenario: 首次打开

- **WHEN** 用户点击「打开万年历…」
- **THEN** 创建 `CalendarRuntime` 与 `CalendarStore`
- **AND** 计算当前月数据并显示窗口

#### Scenario: 默认关闭窗口

- **WHEN** `resident=false` 且用户关闭日历窗口
- **THEN** 窗口、ViewStore、CalendarStore 与 runtime 被释放
- **AND** 再次打开时重新创建

#### Scenario: 常驻内存

- **WHEN** 用户在设置中开启「常驻内存」
- **THEN** 关闭窗口后保留 runtime 与 CalendarStore
- **AND** 关闭「常驻内存」且窗口已关闭时立即释放 runtime

### Requirement: 内置入口

系统 SHALL 注册 `calendar.open` 内置操作，并提供默认「万年历」快捷按钮。

#### Scenario: 手机面板打开日历

- **WHEN** 用户从内置操作添加或使用默认「万年历」按钮
- **THEN** 调用 `calendar.open` 并打开日历窗口
