# system-cleaner 变更（add-puremac-ui-redesign-and-lemon-research）

## ADDED Requirements

### Requirement: PureMac 窗口统一信息架构

PureMac 窗口 SHALL 使用一套统一信息架构：左侧固定导航、右侧内容区按「PageHeader → FilterStrip / 内容 → StatusBar」组织，各页签不得再各自实现标题、统计行或底部操作。

#### Scenario: 打开窗口

- **WHEN** 用户打开 PureMac 窗口
- **THEN** 窗口左侧显示「概览 / 垃圾清理 / 应用卸载 / 大文件 / 重复文件 / 进程」导航
- **AND** 当前页项有强调色竖条与背景，其余项为次要色
- **AND** 右侧内容区顶部显示当前页标题、副标题与主操作
- **AND** 窗口最小宽度 640pt 时，左侧导航收为 56pt 图标栏且不遮挡内容

#### Scenario: 页签切换

- **WHEN** 用户切换页签
- **THEN** 只有内容区替换，导航、PageHeader 结构和 StatusBar 结构保持不变
- **AND** 页签切换不重建已完成的扫描结果

### Requirement: 操作与状态就近呈现

扫描、取消、清理、停止等操作 SHALL 靠近其作用对象，底部状态栏只呈现全局状态，不得同时承担批量操作与全局状态两种语义。

#### Scenario: 待扫描

- **WHEN** 当前页尚无结果
- **THEN** PageHeader 主按钮显示「扫描 / 开始扫描」
- **AND** 内容区显示居中的空态，不叠加筛选条、统计行或脚注
- **AND** StatusBar 显示「就绪 · 上次扫描 …」

#### Scenario: 扫描中

- **WHEN** 扫描进行中
- **THEN** PageHeader 主按钮变为「取消」，StatusBar 显示进度、已处理数量与当前路径
- **AND** 用户点击取消后，扫描在当前检查点停止且不产生删除

#### Scenario: 有结果

- **WHEN** 扫描完成且存在结果
- **THEN** 表格上方显示「共 N 项 · 总大小 / 已选 M 项 · 选中大小」与「全不选 / 清理选中」
- **AND** 清理按钮只在有选中项且空闲时可用
- **AND** StatusBar 不再显示重复的清理按钮

### Requirement: 危险操作分层确认

清理、永久删除、卸载与强制退出 SHALL 在统一弹窗中展示对象、数量与大小，并按危险程度分层确认。

#### Scenario: 移入废纸篓

- **WHEN** 用户确认清理
- **THEN** 弹窗列出条目数量、总大小与「移入废纸篓」文案
- **AND** 默认不勾选永久删除

#### Scenario: 永久删除

- **WHEN** 用户在确认弹窗中开启永久删除
- **THEN** 出现单独的二次确认，明确「不进废纸篓、不可恢复」
- **AND** 未完成二次确认前不执行删除

#### Scenario: keeper 保护

- **WHEN** 重复文件组展示
- **THEN** keeper 行显示「保留」徽标且不可勾选
- **AND** 只有其余副本可被选中删除
