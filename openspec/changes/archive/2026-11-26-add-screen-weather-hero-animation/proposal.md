> 状态：该自写动画上线后用户反馈"上下跳动观感不好"，已于 2026-11-26 被 `replace-screen-weather-hero-icons` 取代并从代码移除。本变更仅保留历史记录。

# 提案：副屏天气主图标轻动效

## Why

副屏天气卡右上角的大图标是页面视觉焦点，但现在是纯静态 SVG，晴、雨、雪、雷、雾都只有形状差异。
在不引入第三方图标库、不改变现有白色细线风格的前提下，给**主图标**加一层克制的循环动画，
能让天气状态一眼可辨，也更像一块"活的"桌面表盘。

## What Changes

- 只对天气卡右上角的**主图标**（`#wxIcon`）启用动画；小时条、5 天预报、宠物环境图标保持静态。
- 沿用现有 `weatherIcon()` 的 24×24 线性 SVG，新增 `weatherHeroIcon()` 输出带分组 class 的版本：
  太阳光线、云层、雨滴、雪花、雾线、闪电分别可独立动画。
- 六类天气各一套 CSS keyframes：
  - 晴：光线缓慢旋转
  - 多云：云层左右轻漂
  - 雨：3 滴雨错峰下落
  - 雪：2 片雪花下落 + 轻微摆动
  - 雾：两条雾线反向缓移
  - 雷：云层轻漂 + 闪电低频闪烁
- 主图标按 icon code 去重渲染：天气轮询返回同一 code 时不重建 DOM，动画不每 30 秒重头开始。
- 尊重 `prefers-reduced-motion`；关闭时全部动画停止，只保留静态图标。
- `ScreenHTML.version` 在实现时提升，强制已打开的副屏重载。

**非目标**：

- 不引入 Meteocons / Lottie / 字体图标等第三方资源。
- 不做白天 / 夜间两套图标；现有分类逻辑不变。
- 不动小时条与预报表的小图标。
- 不做背景、卡片或数字的动画。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：天气主图标新增轻量 CSS 动画，并保证静态降级、单图标渲染与轮询不重启。

## Impact

- 代码：`Panel/Screen/index.html`（CSS、`weatherHeroIcon`、`renderWeather`、`clearWeather`、版本号）。
- 权限/数据：无新增权限与配置键；动画纯前端。
- 体积：只增加 CSS 与分组标签，预计 < 4 KB，不新增资源文件。
- 入口：无新增，仍为 设置 → 副屏。
