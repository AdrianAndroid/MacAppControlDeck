# remote-web-panel 变更（add-hourly-weather-strip）

## MODIFIED Requirements

### Requirement: 副屏天气展示

副屏 SHALL 在同一页面展示实时天气、未来 4 小时与未来 5 天预报；天气数据由 Mac 端代理获取，页面不接触凭据与坐标。

#### Scenario: 天气栏结构

- **WHEN** 横屏且 `/api/weather` 返回 `ok: true`
- **THEN** 右栏自上而下为「城市 / 湿度·降水 / 大图标+大温度 / 体感 / 现在+4 小时 / 5 天预报表 / 更新时间与署名」
- **AND** 城市与更新时间右对齐，预报表按「日期 图标 高温 低温」四列对齐
- **AND** 页面不出现滚动

#### Scenario: 竖屏布局

- **WHEN** 副屏在竖屏加载且天气可用
- **THEN** 自上而下为「时钟 / 天气（含小时条与 5 天预报）/ 月历」
- **AND** 小时条、5 天预报完整可见，字号随视口收窄不溢出

#### Scenario: 实时天气内容

- **WHEN** `/api/weather` 返回 `ok: true`
- **THEN** 显示温度、体感、湿度、降水概率、更新时间和「和风天气」署名
- **AND** 天气图标为单色内联 SVG，不改变月份与今天所用的红色强调

#### Scenario: 5 天预报

- **WHEN** 返回 `daily` 至少 1 项
- **THEN** 纵向展示最多 5 天，每行包含日期/图标/最高/最低温
- **AND** 高温右对齐白色、低温右对齐灰色，四列不串位

#### Scenario: 未配置天气

- **WHEN** 用户未填写和风凭据或未选择城市
- **THEN** 天气列整体隐藏，时钟与月历按两栏填满
- **AND** `/api/weather` 返回 `reason: "not-configured"`

#### Scenario: 数据过期或失败

- **WHEN** 上游请求失败但存在缓存
- **THEN** 继续显示缓存数据并标记「已过期」
- **WHEN** 失败且无缓存
- **THEN** 天气栏显示「天气暂不可用」，时钟与月历不受影响

## ADDED Requirements

### Requirement: 副屏小时预报条

副屏 SHALL 展示「现在 + 未来 4 小时」的天气，数据来自和风 `/weather/v1/hourly`。

#### Scenario: 数据获取

- **WHEN** 天气可用
- **THEN** Mac 端与实时/日预报并行请求小时预报（默认 24 小时）并缓存 5 分钟
- **AND** 小时预报失败不影响实时与日预报，页面隐藏小时条

#### Scenario: 布局

- **WHEN** 横屏天气可用
- **THEN** 小时条位于体感与 5 天预报表之间
- **AND** 5 格等分，每格两行：时间 / 图标+温度
- **AND** 不把 5 天表或更新时间挤出视口

#### Scenario: 时间基准

- **WHEN** 渲染小时标签
- **THEN** 按 Mac 时区把 `forecastTime` 转成「18时」这类标签
- **AND** 第一格固定显示「现在」

#### Scenario: 矮屏

- **WHEN** 可用高度不超过 430px
- **THEN** 压缩天气主视觉与预报行，小时条、5 天表和更新时间都完整可见
