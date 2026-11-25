# 副屏刷新按钮整页重载 + 设置变更即时生效

## 背景

手机副屏点击「↻」刷新按钮看似无效：按钮虽然绑定了 `click`，但原 `refreshAll()` 只重新拉取数据。时间本来每分钟自动更新、倒计时每秒跳步，所以用户看不到任何变化，认为刷新没生效。同时 Mac 端设置变更后，副屏虽能收到 revision 通知，但只做零散的 `loadXxx`，随机桌宠等配置会被保护逻辑挡掉，表现为「设置改了副屏没更新」。

## 目标

- 点击刷新按钮执行真正的整页重载，用户能看到明确变化。
- Mac 端设置变更时副屏约 1 秒内整页重载，应用全部配置。
- 重载不引入循环，首次打开不因历史 revision 误重载。
- 手机等触屏设备控制条常驻，避免 5 秒隐藏后点不到按钮。

## 范围

仅改副屏页面 `Panel/Screen/index.html` 的 JS 与少量 CSS 判断；不改服务端 API、设置模型或 PC 端 UI。

## 实现

1. `hardReload()`：以 `/screen/?v=<版本>&rev=<事件基线>&t=<时间戳>` 整页重载。
2. `refreshAll()` 改为调用 `hardReload('manual')`。
3. 事件轮询发现 revision 变化时调用 `hardReload('event')`，不再零散 load。
4. URL 携带 `rev` 作为新基线并初始化 `screenEventRevision`，`eventRevisionPrimed` 保证首次打开只对齐基线不重载。
5. 触屏设备 `(pointer: coarse)` 时 `keepUIVisible()` 不启动隐藏计时，控制条常驻。
