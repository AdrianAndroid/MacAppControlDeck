# remote-web-panel 变更（expand-screen-weather-icon-mapping）

## MODIFIED Requirements

### Requirement: 主天气图标资源与动画

副屏天气卡主图标 SHALL 在和风 icon code 命中映射时使用 Meteocons Monochrome SVG；
未命中的同族 code SHALL 按天气族兜底；只有无天气语义的 code 才回退旧静态图标。

#### Scenario: 冷热与沙尘

- **WHEN** `now.icon` 为 900（热）/ 901（冷）
- **THEN** 主图标分别使用 `sun-hot` / `thermometer-mercury-cold` 动画 SVG
- **WHEN** code 为 503/504/505/507/508
- **THEN** 主图标使用 `dust` 动画 SVG

#### Scenario: 同族 code 兜底

- **WHEN** 和风返回映射表未列出的 1xx / 3xx / 4xx / 5xx code
- **THEN** 分别兜底到 clear / rain / snow / fog 动画 SVG
- **AND** 150 以上优先夜间版本，350 以上优先夜间降雨版本

#### Scenario: 无法归族

- **WHEN** code 为 999 或无法解析
- **THEN** 主图标回退原有 24×24 静态线性 `weatherIcon(code)`
- **AND** 不空白、不臆造天气

#### Scenario: 其余行为不变

- **WHEN** 渲染小时条、5 天预报或 `prefers-reduced-motion: reduce`
- **THEN** 小图标保持静态；主图标加载 Meteocons 静态版
