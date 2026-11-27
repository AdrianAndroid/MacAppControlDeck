# status-bar 变更（add-calendar-two-month-popover）

## MODIFIED Requirements

### Requirement: 日历图标状态项与月历下拉

万年历模块启用时 SHALL 注册 `calendar.panel` 条目：状态栏只显示日历图标，点击弹 `NSPopover` 双月面板而不是 `NSMenu` 或独立窗口。

#### Scenario: 双月页面
- **WHEN** 面板打开
- **THEN** 一次显示当月 + 下月两页月历，标题为「yyyy年M月 – M月」（跨年显示两个年份）
- **AND** 每页只构建 5–6 行日期格，不预加载前后一年

#### Scenario: 整页翻动
- **WHEN** 点击 `‹` / `›` 或在面板上滚动鼠标滚轮
- **THEN** 整个面板按整月切到上一页/下一页，不滚动内容
- **AND** 触控板一次手势及惯性阶段只翻一页

#### Scenario: 节日显示模式
- **WHEN** 设置 → 万年历选择「日期下方小字」
- **THEN** 支持「关 / 精简 / 全显示」，默认精简
- **AND** 关：不显示农历/节气/节日；精简：只显示节气与传统节日；全显示：显示全部农历/节气/节日
- **AND** 切换模式不改变网格高度；弹窗底部有分段开关，`⋯` 菜单也可切换

#### Scenario: 农历标记而非日程
- **WHEN** 面板渲染任意日期格
- **THEN** 显示公历数字、按模式过滤后的小字、今日蓝色描边与休/班书签
- **AND** 不读取 EventKit 日程、不申请日历权限

#### Scenario: 打开完整万年历
- **WHEN** 用户点击 `⋯` 菜单并选择「打开完整万年历…」
- **THEN** 关闭 popover 并打开现有 `CalendarWindowView` 独立窗口

#### Scenario: 关闭与联动
- **WHEN** 用户再次点击日历图标、点击面板外部，或关闭万年历模块
- **THEN** 面板关闭；模块关闭时状态项也立即消失
