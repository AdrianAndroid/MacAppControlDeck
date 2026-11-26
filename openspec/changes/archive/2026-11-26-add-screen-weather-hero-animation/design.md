# 设计：副屏天气主图标轻动效

## 1. 范围

只动天气卡右上角的大图标 `#wxIcon`：

- 有动画：晴、多云、雨、雪、雾、雷 六类主图标。
- 无动画：小时条 5 个、5 天预报 5 个、湿度/降水文字、温度数字。
- 实现方式：复用现有 24×24 内联 SVG 与 `currentColor`，只给需要动的节点加 class 和 CSS keyframes。

预计新增：CSS < 2 KB、`weatherHeroIcon()` 与分组标签 < 2 KB；不新增图片/字体/JS 依赖。

## 2. 图标分组（按现有六类）

| 分类 | 现有 SVG | 新增分组 |
| --- | --- | --- |
| `sun` | 圆 + 8 条光线 | `.wxa-sun`（整组）、`.wxa-rays`（8 条光线） |
| `cloud` | 1 条云路径 | `.wxa-float` + `.wxa-body` |
| `rain` | 云 + 1 条三滴线段路径 | `.wxa-float` + `.wxa-body` + 3 个独立 `.wxa-drop.d1/.d2/.d3` |
| `snow` | 云 + 1 条雪花路径 | `.wxa-float` + `.wxa-body` + 2 个独立 `.wxa-flake.f1/.f2` |
| `fog` | 云 + 2 条雾线 | `.wxa-float` + `.wxa-body` + `.wxa-fog.f1/.f2` |
| `thunder` | 云 + 闪电 | `.wxa-float` + `.wxa-body` + `.wxa-bolt` |

`weatherIcon(code)` 保持原样，供小时条/预报使用；新增 `weatherHeroIcon(code)` 仅给 `#wxIcon` 使用，结构差异只在分组和 class，线条数据不变。

## 3. 动效参数

原则：**慢、幅度小、可循环、不抢温度数字**。所有动画 1 秒内位移不超过 3 个 viewBox 单位（主图标实际约 58 px，1 单位 ≈ 2.4 px）。

| 分类 | 动画 | 时长 / 缓动 | 幅度 |
| --- | --- | --- | --- |
| 晴 | 光线顺时针旋转 | 24 s linear infinite | 360° |
| 多云 | 整组图标上下浮动 + 云层左右漂 | 上下 3.2 s infinite；左右 5 s alternate | 纵向 ±1 单位（≈±2.4 px）、横向 ±1.2 单位（≈±2.9 px） |
| 雨 | 3 滴雨错峰下落 + 淡入淡出 | 1.5 s cubic-bezier(.4,0,.6,1) infinite，延迟 0 / .28 / .56 s | 下落 3.4 单位，透明度 0→1→0 |
| 雪 | 2 片雪花下落 + 左右轻摆 | 3.6 s ease-in-out infinite，延迟 0 / 1.8 s | 下落 4 单位，横摆 ±0.6 单位 |
| 雾 | 2 条雾线反向缓移 | 5.5 s ease-in-out alternate | ±1.2 单位 |
| 雷 | 云层轻漂 + 闪电低频闪烁 | 云 4.5 s；闪电 5 s linear infinite | 透明度 0.55 → 1 → 0.55，每周期两次 |

闪电不做整屏闪烁、不做颜色变化，仅图标内闪电线条提亮，避免视觉疲劳与光敏风险。

## 4. CSS 草案

```css
.wx-hero-svg { overflow: hidden; }

.wx-hero-svg .wxa-float {
  transform-box: view-box;
  transform-origin: 12px 12px;
  animation: wxa-bob 3.2s ease-in-out infinite;
}
.wx-hero-svg .wxa-body {
  transform-box: view-box;
  transform-origin: 12px 13px;
  animation: wxa-drift 5s ease-in-out infinite alternate;
}
.wx-hero-svg .wxa-rays {
  transform-box: view-box;
  transform-origin: 12px 12px;
  animation: wxa-spin 24s linear infinite;
}
.wx-hero-svg .wxa-drop {
  animation: wxa-rain 1.5s cubic-bezier(.4,0,.6,1) infinite;
}
.wx-hero-svg .wxa-drop.d2 { animation-delay: .28s; }
.wx-hero-svg .wxa-drop.d3 { animation-delay: .56s; }
.wx-hero-svg .wxa-flake {
  animation: wxa-snow 3.6s ease-in-out infinite;
}
.wx-hero-svg .wxa-flake.f2 { animation-delay: 1.8s; }
.wx-hero-svg .wxa-fog.f1 { animation: wxa-fog-a 5.5s ease-in-out infinite alternate; }
.wx-hero-svg .wxa-fog.f2 { animation: wxa-fog-b 5.5s ease-in-out infinite alternate; }
.wx-hero-svg .wxa-bolt { animation: wxa-flash 5s linear infinite; }

@keyframes wxa-spin { to { transform: rotate(360deg); } }
@keyframes wxa-bob {
  0%, 100% { transform: translateY(-1px); }
  50% { transform: translateY(1px); }
}
@keyframes wxa-drift {
  from { transform: translateX(-1.2px); }
  to   { transform: translateX(1.2px); }
}
@keyframes wxa-rain {
  0%, 10% { transform: translateY(-1.2px); opacity: 0; }
  28%, 70% { opacity: 1; }
  100% { transform: translateY(2.2px); opacity: 0; }
}
@keyframes wxa-snow {
  0%   { transform: translate(-.6px, -1.2px); opacity: 0; }
  20%  { opacity: .95; }
  60%  { transform: translate(.6px, 1.6px); opacity: .95; }
  100% { transform: translate(-.4px, 2.8px); opacity: 0; }
}
@keyframes wxa-fog-a {
  from { transform: translateX(-1.2px); }
  to   { transform: translateX(1.2px); }
}
@keyframes wxa-fog-b {
  from { transform: translateX(1.2px); }
  to   { transform: translateX(-1.2px); }
}
@keyframes wxa-flash {
  0%, 84%, 100% { opacity: .55; }
  86% { opacity: 1; }
  88% { opacity: .6; }
  90% { opacity: 1; }
  92% { opacity: .55; }
}

@media (prefers-reduced-motion: reduce) {
  .wx-hero-svg .wxa-float,
  .wx-hero-svg .wxa-body,
  .wx-hero-svg .wxa-rays,
  .wx-hero-svg .wxa-drop,
  .wx-hero-svg .wxa-flake,
  .wx-hero-svg .wxa-fog,
  .wx-hero-svg .wxa-bolt {
    animation: none;
  }
}
```

备注：SVG 内使用 CSS transform 时，分组统一加 `transform-box: view-box`，避免浏览器按元素自身 bounding box 计算原点导致太阳绕错位置。

## 5. 渲染与轮询

现在 `renderWeather()` 每 30 秒 `innerHTML = weatherIcon(now.icon)`，动画会从头播放。改成：

```js
var lastHeroIconCode = null;

function renderHeroIcon(code) {
  var next = code == null ? '' : String(code);
  if (next === lastHeroIconCode) { return; }
  lastHeroIconCode = next;
  wxIcon.innerHTML = next ? weatherHeroIcon(next) : '';
}
```

- 首次渲染、天气状态变化 → 重建，动画自然开始。
- 同一 code 轮询刷新 → 不碰 DOM，动画连续。
- `clearWeather()` 把 `lastHeroIconCode = null` 并清空 `wxIcon`，下次天气恢复时重新入场。

## 6. 降级与性能

- `prefers-reduced-motion: reduce` 下全部 `animation: none`，图标与当前版本像素一致。
- 只动 1 个大图标，CSS 动画由合成器处理，无 JS 定时器；页面隐藏时浏览器自行节流。
- 不改变 SVG 尺寸、`viewBox`、`stroke-width`，不触发重排。
- 动画不改变颜色，只改 transform / opacity，避免重绘整块卡片。

## 7. 验证计划（实现后）

1. 六类天气各渲染一次，截图 0 s / 中段两个时间点，确认无裁切、无描边抖动。
2. 用 `prefers-reduced-motion` 模拟确认完全静止。
3. 连续轮询两次同一 code，确认 `#wxIcon` DOM 未被替换（动画不重启）。
4. 确认小时条、5 天预报的 SVG 不含 `wxa-*` class。
5. 横屏 1788×855、844×390、竖屏 500×900 三视口检查。
6. 无头 Chrome 验证，不启动 App、不抢焦点。

## 8. 不做

- 不做按时间段自动切换白天/夜间图标。
- 不做进入动画（入场淡入 / 弹跳）；只做常驻循环。
- 不做图标外发光、阴影、粒子或背景动画。
