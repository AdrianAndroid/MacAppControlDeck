# remote-web-panel 变更（fix-screen-landscape-layout）

## ADDED Requirements

### Requirement: 横屏副屏三栏布局

横屏且天气可用时，副屏 SHALL 以「时钟 | 月历 | 天气」三栏展示，月历独占整列高度。

#### Scenario: 横屏开启天气

- **WHEN** 视口为横屏且 `/api/weather` 返回可用数据
- **THEN** 时钟、月历、天气分别占据三栏
- **AND** 月历 6 行网格不被压缩，行高与列宽接近
- **AND** 3 天预报在天气栏内垂直排列，显示标签、图标、天气文字与高低温

#### Scenario: 窄横屏

- **WHEN** 横屏宽度小于 700px
- **THEN** 月份标题按列宽缩放，不与天气栏重叠

#### Scenario: 竖屏开启天气

- **WHEN** 视口为竖屏且天气可用
- **THEN** 时钟占 40% 高度
- **AND** 底部 3 天预报完整可见，不被视口裁掉

#### Scenario: 大屏

- **WHEN** 视口高度不小于 700px
- **THEN** 月历网格限制高度并整体居中，单元格保持接近方形

#### Scenario: 未配置天气

- **WHEN** 天气未配置或不可用
- **THEN** 保持「时钟 + 月历」两栏布局，不出现空的第三栏
