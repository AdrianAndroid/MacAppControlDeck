# remote-web-panel 变更（refresh-screen-weather-ui）

## MODIFIED Requirements

### Requirement: 副屏天气展示

副屏 SHALL 在同一页面展示实时天气与未来 5 天预报；天气数据由 Mac 端代理获取，页面不接触凭据与坐标。

#### Scenario: 天气栏结构

- **WHEN** 横屏且 `/api/weather` 返回 `ok: true`
- **THEN** 右栏自上而下为「城市 / 湿度·降水 / 大图标+大温度 / 体感 / 5 天预报表 / 更新时间与署名」
- **AND** 城市与更新时间右对齐，预报表按「日期 图标 高温 低温」四列对齐
- **AND** 页面不出现滚动

#### Scenario: 竖屏布局

- **WHEN** 副屏在竖屏加载且天气可用
- **THEN** 自上而下为「时钟 / 天气（含 5 天预报）/ 月历」
- **AND** 5 天预报完整可见，字号随视口收窄不溢出

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

### Requirement: 横屏副屏三栏布局

横屏且天气可用时，副屏 SHALL 以「时钟 | 月历 | 天气」三栏严格等宽展示；三栏使用同一套头部节奏，视觉重量一致。

#### Scenario: 横屏开启天气

- **WHEN** 视口为横屏且天气可用
- **THEN** 三栏各占 `1fr`，栏距相同，三栏 kicker 与分隔线在同一基线
- **AND** 月历独占整列高度，5–6 行网格不被压缩，行高与列宽接近
- **AND** 天气栏为 MagicMirror 结构：城市 / 湿度降水 / 大图标+温度 / 体感 / 5 天预报表
- **AND** 页面不出现滚动

#### Scenario: 窄横屏

- **WHEN** 横屏宽度小于 700px
- **THEN** 月份标题按列宽缩放，不与天气栏重叠
- **AND** 预报表四列仍对齐，天气块不溢出

#### Scenario: 竖屏开启天气

- **WHEN** 视口为竖屏且天气可用
- **THEN** 自上而下为「时钟 → 天气 → 月历」，时钟不超过 24% 高度
- **AND** 5 天预报完整可见，月历 5 行不重叠

#### Scenario: 大屏

- **WHEN** 视口高度不小于 700px
- **THEN** 月历网格限制高度并整体居中，单元格保持接近方形

#### Scenario: 未配置天气

- **WHEN** 天气未配置或不可用
- **THEN** 保持「时钟 + 月历」两栏布局，不出现空的第三栏

### Requirement: 和风 v1 日预报字段兼容

5 天预报 SHALL 正确解析和风 v1 的 `days`、`daytime.condition.code`、`temperatureMax/Min.value` 与降水概率字段。

#### Scenario: 真实 v1 响应

- **WHEN** 日预报返回 `days[].daytime.condition.text/code`
- **THEN** 页面显示对应天气图标与高低温
- **AND** 不再显示「—」或统一云图标

#### Scenario: 旧字段回退

- **WHEN** 响应只含 `daily[].day.condition` 或 `textDay/iconDay`
- **THEN** 仍按旧字段解析，不回归

#### Scenario: 输出上限

- **WHEN** 上游返回超过 5 天
- **THEN** `/api/weather` 最多输出 5 天，页面最多展示 5 天
