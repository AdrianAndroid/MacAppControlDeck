# 提案：副屏主天气图标换用 Meteocons Monochrome

## Why

自写的"整颗图标上下浮动"真实上线后观感不好，用户要求换成成套的动图 UI。
调研结论（`Docs/research/2026-11-26-animated-weather-icons.md`）显示 Meteocons 的
Monochrome 动画 SVG 最贴合黑底白线副屏：MIT、离线可内置、白天/夜间/雾霾/雨雪齐全。

## What Changes

- 主图标 `#wxIcon` 改为 Meteocons Monochrome 动画 SVG；小时条与 5 天预报继续使用现有静态细线图标（Phase A）。
- 只 vendor 映射用到的 28 个动画 SVG + 28 个静态 SVG；新增 `/screen/icons/<name>.svg` 只读路由。
- 和风 icon code 逐个映射到资源名；未映射（900/901/999 等）或加载失败回退现有 `weatherIcon()`。
- `prefers-reduced-motion: reduce` 时加载 **static 版本**，避免停在动画的透明帧；偏好变化时自动重载。
- 删除上一版自写的 `.wxa-*` 动画与 `weatherHeroIcon()`，不再叠加。
- 新增 `Resources/Licenses/Meteocons-LICENSE.txt` 与 `THIRD_PARTY_NOTICES.md` 记录。
- `ScreenHTML.version` 提升到 `2026-11-27.14`。

**非目标**：

- 不改小时条/预报小图标（Phase B）。
- 不放宽和风 code 白名单，不执行远程资源。
- 不引入 Lottie、字体或 JS 动画运行时。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：主天气图标改为第三方动画资源，带 code 映射、静态降级与旧图标回退。

## Impact

- 代码：`Panel/Screen/index.html`、`Panel/Screen/icons/*.svg`、`Panel/ScreenHTML.swift`、
  `Server/APIRouter.swift`、`UI` 无改动。
- 体积：+约 282 KB 资源；App 36 MB / universal 55 MB，可忽略。
- 权限/数据：无新增权限与配置键。
- 入口：无新增，仍为设置 → 副屏。
