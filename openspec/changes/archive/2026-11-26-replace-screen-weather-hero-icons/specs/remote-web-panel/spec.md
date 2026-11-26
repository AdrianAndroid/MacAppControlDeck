# remote-web-panel 变更（replace-screen-weather-hero-icons）

## ADDED Requirements

### Requirement: 主天气图标资源与动画

副屏天气卡主图标 SHALL 在和风 icon code 命中映射时使用 Meteocons Monochrome SVG；小时条与预报小图标 MUST 保持现有静态图标。

#### Scenario: 命中映射

- **WHEN** `now.icon` 为 100 / 104 / 305 / 400 / 501 等已映射 code
- **THEN** 主图标加载 128×128 的 Meteocons Monochrome SVG
- **AND** 默认播放 SVG 自带动画；同一 code 的 30 秒轮询不重建 DOM

#### Scenario: 未命中或加载失败

- **WHEN** code 为 900 / 901 / 999 或不在映射表内，或资源请求失败
- **THEN** 主图标回退到原有 24×24 静态线性 `weatherIcon(code)`
- **AND** 不出现空白图标或控制台阻断性错误

#### Scenario: 减少动态

- **WHEN** `prefers-reduced-motion: reduce`
- **THEN** 主图标加载 Meteocons 静态 SVG，不播放 SMIL 动画
- **AND** 静态图标完整可见，不停在动画的透明帧

#### Scenario: 小图标不变

- **WHEN** 渲染小时条与 5 天预报
- **THEN** 这些位置继续使用现有静态 `weatherIcon()`
- **AND** 不请求 `/screen/icons/`

#### Scenario: 只读路由

- **WHEN** 请求 `GET /screen/icons/<name>.svg`
- **THEN** 仅当 `<name>` 匹配 `^[a-z0-9-]{1,64}$` 且资源存在时返回 `image/svg+xml`
- **AND** 非法文件名或缺失资源返回 404，页面回退旧图标
