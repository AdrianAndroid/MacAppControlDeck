# 设计：手机副屏页面

## 1. 为什么是独立页面，而不是复用 `/panel/`

- `/panel/` 的职责是控制：配对、按钮、状态反馈、队列。副屏的职责是展示：时钟与日期。
- 复用面板意味着要么给面板加一套「展示模式」，要么在配对后隐藏控件；两者都会让面板状态机更难维护。
- 独立静态页面可以做到**零 API、零 token**：安全边界清晰，地址可以直接抄给另一台手机，不需要任何配对步骤。

## 2. 路由与缓存

- 入口：`/screen`、`/screen/`、`/screen/index.html` 一律 302 到 `/screen/?v=<ScreenHTML.version>`。
- 直接请求 `/screen/?v=…` 返回 `text/html`，`Cache-Control: no-store, must-revalidate`。
- 版本号独立于 `PanelHTML.version`（`2026-11-23.1` 起步），改版时提升版本即可让旧缓存失效。
- 与其他静态页一致：Host 白名单校验保留；副屏不新增 API，所以不影响鉴权链路。

## 3. 页面结构

```
.frame
├── .stage            （横屏：左右；竖屏：上下）
│   ├── .clock        （canvas，DPR 缩放绘制）
│   └── .calendar
│       ├── 月份标题 + ‹ ›
│       ├── S M T W T F S
│       └── 6×7 日期网格
├── .chrome           （点按唤出的控制条）
└── .sheet            （尺寸 / 全屏 / 常亮）
```

- 时钟用 canvas 而不是 DOM/SVG：刻度、指针和圆角端点一次绘制完成，DPR 下始终清晰，尺寸变化只需按容器重算半径。
- 月历用 CSS Grid，固定 6 行，避免切换月份时高度跳动；行高按容器剩余空间等分。
- 横竖屏用 `@media (orientation: …)` 切换 `flex-direction`；320×568 到 1440×900 均不出现滚动。
- 绘制节流到约 15fps，`document.hidden` 时暂停 `requestAnimationFrame`，避免旧手机长时间亮屏空转。

## 4. 三档尺寸

- `data-size="s|m|l"` 控制 `--scale`（0.82 / 1 / 1.18），所有字号、间距、圆角都乘以该系数。
- 选择写入 `localStorage["deck_screen_size"]`，刷新与重开浏览器后保持。
- 默认 `m`。控制条里用三枚胶囊切换，立即生效。

## 5. 交互与常亮

- 点按页面任意空白处唤出控制条，5 秒后自动隐藏；点控制条本身不重新计时，避免误触。
- Wake Lock：页面加载后尝试申请；失败（需手势、旧浏览器）则在下一次点按时重试；`visibilitychange` 回到前台时重新申请。不可用时控制条显示「常亮不可用」，不假装已开启。
- 全屏：仅在 `document.documentElement.requestFullscreen` 存在时显示按钮；iOS Safari 不支持网页全屏，按钮隐藏，由「添加到主屏幕」达到近似效果。
- 月份浏览：`‹ ›` 检查 60 秒空闲计时；浏览他月后自动回到当月，保证副屏不会停在历史月份。

## 6. Mac 端入口

- `LANAddress.screenURL(port:)` 与 `panelURL(port:)` 同源，避免 IP 解析分叉。
- `DeckState` 暴露 `screenURL`、`screenAddressText`、`copyScreenURL()`、`openScreenInBrowser()`。
- 菜单栏「电脑控制」：新增副屏两行（打开 / 复制），排在面板地址之后。
- 设置 → 服务：新增「副屏」卡片，说明「只读、免配对」，与远程面板并列。
- 内置操作 `screen.open`（名称「打开副屏」）：满足 R0，可从按钮管理添加，并自动出现在菜单栏快捷操作和手机面板快捷操作。

## 7. 已知限制

- 副屏显示的是**手机本地时间**；Mac 与手机不在同一时区时会不一致，属预期行为。
- iOS 省电模式或锁屏会挂起页面，Wake Lock 不保证生效；这是系统限制，页面不做虚假承诺。
- 副屏地址与面板同端口，明文 HTTP；同网段设备可以打开，但只能看到时间与日历，不能执行任何动作。
