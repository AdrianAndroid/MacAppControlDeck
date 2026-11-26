# remote-web-panel 变更（add-screen-weather-hero-animation）

## ADDED Requirements

### Requirement: 天气主图标轻动效

副屏天气卡主图标 SHALL 按天气类型播放克制的循环动画；小时条与预报小图标 MUST 保持静态。

#### Scenario: 六类天气

- **WHEN** 主天气分别为晴 / 多云 / 雨 / 雪 / 雾 / 雷
- **THEN** 主图标分别表现为光线旋转 / 云层轻漂 / 雨滴错峰下落 / 雪花下落轻摆 / 雾线反向缓移 / 闪电低频闪烁
- **AND** 动画只改 transform 与 opacity，不改变尺寸、颜色与布局

#### Scenario: 小图标静态

- **WHEN** 渲染小时条与 5 天预报
- **THEN** 这些位置的 SVG MUST NOT 带 `.wxa-*` 动画分组或 animation

#### Scenario: 轮询不重启

- **WHEN** 30 秒轮询返回与上次相同的 icon code
- **THEN** `#wxIcon` DOM MUST NOT 被替换，动画连续播放
- **AND** icon code 变化时才重建图标

#### Scenario: 减少动态

- **WHEN** 系统开启「减少动态效果」（`prefers-reduced-motion: reduce`）
- **THEN** 主图标所有动画停止，显示与静态版本一致的图标

#### Scenario: 天气清空

- **WHEN** 天气变为未配置或清除
- **THEN** 主图标被清空并重置缓存，下次恢复时重新按新 code 渲染

## MODIFIED Requirements

### Requirement: 天气卡主图标

天气主图标 SHALL 继续使用 24×24、`stroke="currentColor"`、1.5 描边的线性 SVG，不引入外部图标资源。
