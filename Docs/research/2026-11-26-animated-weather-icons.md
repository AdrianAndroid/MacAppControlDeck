# 副屏天气图标换用动画资源调研

日期：2026-11-26
状态：调研完成；已确认 **Monochrome + Phase A + 新增 MIT 许可证**，实现见 `openspec/changes/archive/2026-11-26-replace-screen-weather-hero-icons/`。

## 结论

- **首选 Meteocons（Monochrome + animated SVG）**：MIT、离线可内置、475+ 图标/风格、白天/夜间/雨雪雾霾齐全，动画由 SVG 自带 SMIL 完成，不引入 JS 运行时。
- 推荐**只替换主图标（58px）+ 小图标用同套静态版**：主图标播放缩略动画，小时条/5 天预报保持静态，风格统一。
- 代码若没有对应资源，**逐 code 回退到现有 `weatherIcon()` 静态 SVG**，满足"有的替换、没有的保留"。
- amCharts 动画图标风格偏彩色扁平、只有 23 个且没有雾，CC BY 4.0 还要显著署名；Skycons/Weather Icons 要么太旧要么没有动画；Lottie 需要额外运行时，均不推荐。

## 约束

1. 副屏离线、局域网自托管，资源必须随 App 打包，不能引 CDN。
2. 页面是黑底纯白细线 UI，图标替换后不能破坏现有排版与留白。
3. 只替换图标资源，不改三栏布局、字号、温度/湿度信息层级。
4. 引入第三方资源必须能写进 `THIRD_PARTY_NOTICES.md`，许可证要允许商业分发。
5. 现有自写的"上下跳"动画评价不好，替换时应**整段移除**，不要再叠加。

## 候选对比

| 资源 | 数量/风格 | 动画实现 | 许可证 | 体积（实测/估算） | 适配度 |
| --- | --- | --- | --- | --- | --- |
| **Meteocons** | 475 动画 + 519 静态 / 风格（fill/flat/line/monochrome） | SVG SMIL；另有 Lottie | **MIT** | 单图标中位 ~4.7KB；24 个常用动画图标 ~103KB，静态 ~69KB | **最高**：数量、夜间、雾/霾/沙尘、闪电齐全；Monochrome 与黑底白线最接近 |
| amCharts Free Animated Icons | 23（晴 2 / 多云 7 / 雨雷 8 / 雪 6） | SVG 内嵌 CSS keyframes | CC BY 4.0（必须署名 amCharts） | 2–16KB/个 | 中：风格彩色扁平，**没有雾**，夜间与细分天气不足，需额外署名 |
| Skycons（Dark Sky） | 10 | Canvas JS 逐帧 | 公有领域 | ~十几 KB JS | 低：2013 年视觉，无雾/夜间/强度细分 |
| Weather Icons（erikflowers） | 222 | 静态字体/CSS | 字体 SIL OFL / 代码 MIT | 小 | 低：**没有动画** |
| 和风官方图标 | 约 60 个 code | 静态 SVG / 图标字体 | 文档称"开源"，未列具体许可证 | 小 | 只能保留现状或自己加 CSS |
| Lottie 天气包 | 视素材包 | Lottie JSON + `lottie-web` | 各包不同 | 运行时 300KB+，完整包几十 MB | 低：副屏不值得引入 |

参考：
- https://meteocons.com/ · https://github.com/basmilius/meteocons
- https://www.amcharts.com/free-animated-svg-weather-icons/
- https://github.com/darkskyapp/skycons
- https://github.com/erikflowers/weather-icons
- https://dev.qweather.com/docs/resource/icons/

## 视觉验证

截图（黑底、按副屏实际尺寸渲染）：

- `Docs/research/animated-weather-icons/meteocons-styles-96.png`：96px 下 Monochrome / Line / Fill 三风格对比。
- `Docs/research/animated-weather-icons/meteocons-sizes-58-28-23.png`：58px（主图标）、28px（小时条）、23px（预报）可读性。
- `Docs/research/animated-weather-icons/amcharts-styles-96.png`：amCharts 彩色扁平风格。

观察：

- **Monochrome 最接近现有 UI**：反色后是白描边+黑挖空，仍保持"白线黑底"。已确认 Monochrome 全部图标只用 `black` / `white` / `none` 三种颜色，可安全用 `filter: invert(1)` 或替换为 `currentColor` + 背景色。
- Line 风格带黄色太阳、蓝色雨滴，会给纯黑白副屏引入第二套色板，不建议。
- Fill 风格更"实心"，做主图标很醒目，但 23px 预报里会变成小色块，不建议全站使用。
- 23px 下 Monochrome 的雨滴、雪花很细，仍可辨认但偏密；因此**小图标继续用现有细线版**也是一种合理选择（见下方两阶段方案）。

## SMIL 可行性

已在本机用内联 SVG 实测：

- `svg.getCurrentTime()` 在 1.5s → 2.3s 间持续增长，Meteocons 的 SMIL 动画会自动播放。
- 全部 6 个测试图标 `animationsPaused() === false`。
- 支持 `svg.pauseAnimations()`，可用于「减少动态效果」降级。

风险：Chrome/Safari 目前都支持 SMIL，但它是历史特性；实现后需在 iPhone Safari 真机走查一次。若真机异常，可退回 Meteocons 静态 SVG（同套资源）或保留现有静态图标。

## 推荐替换策略（两阶段）

### Phase A：主图标先换（推荐先做）

- 主图标 `#wxIcon` 改为 Meteocons **Monochrome 动画版**。
- 小时条、5 天预报暂用现有 `weatherIcon()` 静态细线图标（23–28px 下更清晰）。
- 自写的 `wxa-*` 动画与 `weatherHeroIcon()` 整段删除，不再叠加。
- 天气 code 有映射才替换，没有映射回退现有静态图标。

### Phase B：小图标统一（可选）

- 小时条/预报换成 Meteocons **Monochrome 静态版**，与主图标统一。
- 若 23px 可读性不达标，保留当前细线图标，仅主图标换新。

## QWeather code → Meteocons 映射草案

> 和风夜间 code（150–153 / 350–353 / 450–456）未在官方图标页完整列出，以下按已知夜间码准备，实现前需用真实 API 响应核对。

| 和风 code | 含义 | Meteocons（日/夜） |
| --- | --- | --- |
| 100 / 150 | 晴 | `clear-day` / `clear-night` |
| 101 / 151 | 多云 | `partly-cloudy-day` / `partly-cloudy-night` |
| 102 / 152 | 少云 | `mostly-clear-day` / `mostly-clear-night` |
| 103 / 153 | 晴间多云 | `partly-cloudy-day` / `partly-cloudy-night` |
| 104 | 阴 | `overcast-day` / `overcast-night`（或 `overcast`） |
| 300 / 350 | 阵雨 | `partly-cloudy-day-rain` / `partly-cloudy-night-rain` |
| 301 / 351 | 强阵雨 | `overcast-day-rain` / `overcast-night-rain` |
| 302 / 303 / 352 / 353 | 雷阵雨 | `thunderstorms-day-rain` / `thunderstorms-night-rain` |
| 304 / 354 | 雷阵雨伴冰雹 | `thunderstorms-day-hail` / `thunderstorms-night-hail` |
| 305 / 309 | 小雨 / 毛毛雨 | `drizzle` |
| 306 / 314 | 中雨 | `rain` |
| 307 / 315–318 | 大雨到特大暴雨 | `extreme-rain` |
| 308 / 310–312 | 极端降雨 / 暴雨 | `extreme-rain` |
| 313 | 冻雨 | `sleet` |
| 399 | 雨 | `rain` |
| 400 / 408 | 小雪 | `snow` |
| 401 / 402 / 409 / 410 | 中到大雪 | `snow` / `extreme-snow` |
| 403 | 暴雪 | `extreme-snow` |
| 404 / 405 / 406 | 雨夹雪 / 雨雪 | `sleet` |
| 407 | 阵雪 | `partly-cloudy-day-snow` / `partly-cloudy-night-snow` |
| 499 | 雪 | `snow` |
| 500 | 薄雾 | `mist` |
| 501 / 509 / 514 / 515 | 雾 / 浓雾 | `fog` / `fog-day` / `fog-night` |
| 502 / 511–513 | 霾 | `haze` |
| 503 / 504 / 507 / 508 | 扬沙 / 浮尘 / 沙尘暴 | `wind-dust`（视觉近似） |
| 900 / 901 / 999 | 热 / 冷 / 未知 | **回退现有静态图标** |

其他无法识别的 code 一律回退现有 `weatherKind()` + `weatherIcon()`。

## 无缝替换的工程方案

1. **资源落盘**
   - `Sources/MacAppControlDeck/Panel/Screen/icons/animated/monochrome/<name>.svg`
   - `Sources/MacAppControlDeck/Panel/Screen/icons/static/monochrome/<name>.svg`
   - 只放映射表用到的子集（Phase A 约 30 个动画文件，Phase B 再加约 30 个静态文件）。
   - 新增 `Resources/Licenses/Meteocons-LICENSE.txt`，同步 `THIRD_PARTY_NOTICES.md`。

2. **渲染接口**
   - `weatherAssetName(code)` 返回资源名或 `null`。
   - `weatherHeroIcon(code)`：命中 → 加载/内联动画 SVG；未命中或加载失败 → 现有静态 `weatherIcon(code)`。
   - 小图标：命中 → 静态 SVG（建议 `<img>` 直接引用，浏览器缓存）；未命中 → 现有 `weatherIcon(code)`。
   - 同一 code 的 30 秒轮询不重建 DOM，动画连续。

3. **颜色**
   - Monochrome 只有 `black`/`white`/`none`，推荐 `filter: invert(1)` 直接适配黑底。
   - 若后续要做主题色，改为把 `stroke="black"`/`fill="black"` 替换成 `currentColor`，`fill="white"` 替换为背景色。

4. **减少动态**
   - `prefers-reduced-motion: reduce` 时对主图标调用 `svg.pauseAnimations()`，或改为加载静态版；小图标本来就是静态。

5. **验收**
   - 主图标 6 类 + 夜间、雨雪强度、雾霾共 ~12 个代表 code；58px 下无裁切。
   - 23/28px 小图标可读性；不达标就保留旧图标（Phase A）。
   - iPhone Safari 真机确认 SMIL 动画、`pauseAnimations`、无布局位移。
   - 体积增量：Phase A 约 +100KB，Phase A+B 约 +170KB；App 当前 36MB / universal 55MB，可忽略。

## 风险

- **SMIL 兼容性**：目前 Chrome/Safari 正常，但属于历史特性；保留静态版作为一键回退。
- **映射错误**：和风夜间 code 与极端天气 code 覆盖不全；映射表必须带兜底，不能因未知 code 导致空白。
- **风格混合**：Phase A 主图标用新套、小图标用旧细线，可能出现轻微风格差异；先看截图再决定是否进入 Phase B。
- **资源更新**：Meteocons 仍在小版本迭代（npm 0.1.0），应锁定版本并保留 LICENSE 与来源记录。

## 待确认

1. 是否接受 **Monochrome** 风格（最贴合当前黑白 UI），还是想看 Fill / Line 的主图标效果？
2. 先做 **Phase A（只换主图标）**，还是主图标 + 小图标一起换？
3. 是否同意在 App 内新增 Meteocons MIT 许可证与 `THIRD_PARTY_NOTICES.md` 记录？
