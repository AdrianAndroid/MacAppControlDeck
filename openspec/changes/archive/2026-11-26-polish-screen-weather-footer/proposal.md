# Change: 天气卡底栏合并为一行署名

## Why

副屏天气卡底部原先是两行：2.7u 纯白右对齐的「海淀」+ 2.05u 灰色的「更新 … · 和风天气」。城市名比下面的署名大 32%，又单独占一行、贴在最底部，看起来像一句突兀的签名；外层还是固定 120px 的 dock，把预报表格挤短并留出一块空洞。

## What Changes

1. 底栏合并成一行：`海淀 · 更新 09:52 · 和风天气`（过期时追加「· 已过期」）。
2. 字号与颜色统一：城市不再放大、不再用纯白，整行统一 `--muted` 2.05u；「已过期」保留橙色告警色。
3. 底栏高度改为内容自适应（`flex: 0 0 auto; height: auto`），5 天预报因此多出 30–40px 高度，底栏自然贴住卡片下沿。
4. 城市文案改用 DOM `textContent` 注入（原来是 `innerHTML` 拼接），避免城市名被当 HTML 解析。
5. `ScreenHTML.version` → `2026-11-26.2`。

## Capabilities

- `remote-web-panel`（修改）：天气卡底部署名行的排版与颜色层级。

## Impact

- 只改 `Panel/Screen/index.html`（CSS / markup / renderWeather）与版本号。
- 移除 `#wxCity` 元素；天气关闭/异常时底栏为空，与之前「显示 WEATHER 占位」不同。
- 不涉及 `/api/weather` 契约与缓存。

## Non-goals

- 不把城市移到卡片顶部（方案 C 已评估，本轮不做）。
- 不改 5 天预报字段与图标。
