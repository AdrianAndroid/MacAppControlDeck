# 设计：副屏主天气图标换用 Meteocons Monochrome

## 资源与许可

- 上游：https://github.com/basmilius/meteocons
- 包：`@meteocons/svg` 0.1.0（动画 SMIL）+ `@meteocons/svg-static` 0.1.0（静态）
- 许可证：MIT，全文见 `Resources/Licenses/Meteocons-LICENSE.txt`
- 落盘：
  - 动画：`Sources/MacAppControlDeck/Panel/Screen/icons/<name>.svg`
  - 静态：`Sources/MacAppControlDeck/Panel/Screen/icons/static-<name>.svg`
  - 共 28 组（动画 + 静态各 28 个），约 282 KB。

## 渲染流程

1. `weatherHeroAsset(code)` 查映射表；未命中直接 `weatherIcon(code)`（旧细线图标）。
2. 命中后按 `prefers-reduced-motion` 选择 `static-<name>.svg` 或 `<name>.svg`。
3. `fetch('/screen/icons/...svg?v=<version>')` → 内联到 `#wxIcon`。
4. 动画版加 `wx-asset`，CSS `filter: invert(1)` 把 Meteocons 的 black/white 适配黑底；
   静态版使用 `currentColor`，加 `wx-asset-static`，不做反色。
5. 同一 code 的 30 秒轮询不重建 DOM；token 防止旧请求覆盖新天气。
6. 请求失败或资源不存在 → 回退旧 `weatherIcon(code)`，不出现空白。

## 减少动态

- `prefers-reduced-motion: reduce` → 加载静态 SVG，而不是暂停动画版（避免停在透明帧）。
- 偏好运行中切换 → 清空 code 缓存并按新偏好重新加载。
- 页面隐藏时 `pauseAnimations()`，恢复可见时按偏好 `unpauseAnimations()`；静态版无副作用。

## 映射

与调研文档一致：100/150、101/151、102/152、103/153、104/154、300–304/350–354、
305/309、306/314、307/308/310–312/315–318、313、399、400–410/450–456、499、
500–515、900/901/999 中含资源的 code 使用新图标；`900/901/999` 与未知 code 回退旧图标。

夜间与极端天气 code 需在真实 API 响应中复核；映射是纯函数，增删一行即可调整。

## 路由

`GET /screen/icons/<name>.svg`：

- 只接受 `^[a-z0-9-]{1,64}$` 的文件名，路径穿越直接 404。
- 从 `Bundle.module` 的 `Screen/icons` 读取；`Content-Type: image/svg+xml`。
- `Cache-Control: public, max-age=86400`，页面 URL 带 `?v=<ScreenHTML.version>` 做版本失效。
- 无鉴权，与 `/screen/` 一致；不包含用户数据。

## 验证

- 单测：动画资源存在且含 `<animate>`；静态资源无动画；非法文件名返回 nil；页面不含 `wxa-`。
- 无头浏览器：`viewBox="0 0 128 128"`、SMIL 节点数、静态降级 `smilNodes=0`、小图标仍为旧静态。
- 真机：iPhone Safari 刷新后看天气栏左上角大图标；点 ↻ 强制重载。
