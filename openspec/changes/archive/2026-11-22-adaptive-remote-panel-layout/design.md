# 技术设计：电脑控制面板横竖屏布局重做

## 1. 现状约束

- 面板 HTML 全部内联在 `Sources/MacAppControlDeck/Panel/PanelHTML.swift`，不引入外部 CSS/JS 文件。
- 当前结构：`header` + `#main`（`#appsZone` + `#shortcutsZone`）。
- 当前问题：
  - `#shortcutsZone` 使用 `position:fixed` 贴底，`#main` 用 `--quick-h` 预留高度。
  - `scRows=3` 写死，`shortcutPagesEl.style.height = 3*72+2*10+2`。
  - 横屏只改 padding 和按钮高度，没有左右分栏。
  - `render()` 每次调用都重新绑定 `resize/orientationchange`，存在重复监听风险。
  - 判断横屏只靠 `orientation`，窗口宽高变化时列数/行数不重算。

## 2. 布局模型

### 2.1 根容器

```css
html, body { height: 100%; }
body {
  position: fixed; inset: 0;
  overflow: hidden;
  overscroll-behavior: none;
  display: flex; flex-direction: column;
  padding: calc(env(safe-area-inset-top) + 10px) calc(env(safe-area-inset-right) + 12px) 0 calc(env(safe-area-inset-left) + 12px);
}
#main {
  flex: 1 1 auto; min-height: 0; overflow: hidden;
  padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 2px);
}
```

- 用固定根容器避免 iOS 工具栏导致的高度跳变。
- 页面不再依赖 `--quick-h` 预留底部；`#shortcutsZone` 回到正常 flex 流。

### 2.2 竖屏

```css
#main { flex-direction: column; gap: var(--gap); }
#appsZone { flex: 1 1 auto; min-height: 0; }
#shortcutsZone { flex: 0 0 auto; border-top: 1px solid var(--line); padding-top: var(--gap); }
#shortcutPages .page {
  grid-template-columns: repeat(4, minmax(0, 1fr));
  grid-template-rows: repeat(2, minmax(0, 1fr));
}
```

- 快捷区高度由 2 行卡片决定，不再写死。
- 应用区占剩余高度，行数按实测高度计算。

### 2.3 横屏

```css
@media (orientation: landscape) {
  #main { flex-direction: row; gap: var(--gap); }
  #appsZone { flex: 1 1 auto; }
  #shortcutsZone {
    flex: 0 0 var(--rail-w, 140px);
    border-top: 0;
    border-left: 1px solid var(--line);
    padding: var(--gap) 0 0 var(--gap);
  }
  #shortcutPages .page {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    grid-template-rows: repeat(4, minmax(0, 1fr));
  }
  #shortcutPages .btn {
    width: auto;
    height: 100%;
    max-width: 100%;
    aspect-ratio: 1;
    justify-self: center;
    align-self: center;
  }
}
```

- 横屏不再把快捷区贴底，应用区不再被压缩。
- 应用区改为 4 列，填满右侧方形键盘之外的宽度。
- 右栏宽度 `--rail-w` 由 JS 按「当前可用高度的 4 行方形按钮」反推，不固定 60/40。
- 右栏 4 行靠上排；按钮以行高为边长做正方形，不足 8 个时用透明占位保持网格。

### 2.4 宽屏窗口

```css
#main, header { width: 100%; max-width: 1280px; margin: 0 auto; }
```

- 手机全宽；桌面/平板窗口居中并限制最大宽度，避免卡片过大。

## 3. 尺寸系统

```css
:root {
  --u: clamp(3.2px, 1vmin, 4.8px);
  --gap: calc(var(--u) * 2.5);
  --app-cols: 2;
  --app-rows: 4;
  --sc-cols: 4;
  --sc-rows: 2;
  --sc-cell: clamp(60px, 9vh, 80px);
  --icon: clamp(32px, 10.5vmin, 44px);
  --label: clamp(11px, 3.1vmin, 13px);
  --radius: calc(var(--u) * 4);
  --rail-w: 140px;
}
```

- 间距、圆角、内边距按 `--u` 缩放。
- 卡片高度、图标、字号使用 `clamp`，小屏不低于触控下限，大屏封顶。
- 竖屏快捷区用 `--sc-cell` 固定 2 行高度；横屏改由右栏实测高度反推方形边长。
- 不使用 `transform: scale()` 缩放整个面板。

紧凑档：

```css
@media (max-height: 360px) {
  :root { --u: 3px; --gap: 5px; --sc-cell: 52px; --icon: 32px; --label: 11px; }
}
```

## 4. 列数与行数

### 4.1 列数

| 模式 | 应用 | 快捷 |
|---|---|---|
| 竖屏 | 2 | 4 |
| 横屏 | 4 | 2 |

### 4.2 应用区行数

```js
const vmin = Math.min(innerWidth, innerHeight);
const gap = px(getComputedStyle(mainEl).gap) || 8;
const minH = Math.max(64, Math.min(88, vmin * 0.20));
const available = appsPagesEl.clientHeight;
const rows = clamp(Math.floor((available + gap) / (minH + gap)), 2, landscape ? 4 : 6);
```

- 横屏夹在 2–4 行，竖屏夹在 2–6 行。
- 行数变化后重新分页，不改变按钮顺序。
- 底部快捷区不再是固定像素预留，应用区行数由实际剩余高度决定。

### 4.3 快捷区行数

- 竖屏固定 2 行、4 列；`#shortcutPages` 高度由 `--sc-rows`、`--sc-cell` 和 `--gap` 计算。
- 横屏固定 4 行、2 列；`#shortcutPages` 跟随右栏剩余高度。
- 快捷区不参与动态行数计算，保证每页 8 个、高度稳定。

### 4.4 横屏右栏宽度

横屏右栏不按固定百分比，而是由「4 行方形按钮」反推：

```js
rootStyle.setProperty('--rail-w', '140px');       // 临时宽度，让右栏拿到真实高度
const gap0 = px(getComputedStyle(mainEl).gap) || 8;
const pagesH = shortcutPagesEl.clientHeight || 0;
const card = Math.max(52, (pagesH - gap0 * 3) / 4);
const railW = card * 2 + gap0 * 3;
rootStyle.setProperty('--rail-w', railW + 'px');
```

- 先给临时宽度，读取快捷区真实可用高度，再按 4 行反推方形边长与右栏宽度；左应用区自动吃掉剩余宽度。
- 右栏按钮以行高为边长（`height:100%; width:auto; aspect-ratio:1`），宽高一致且不会超出 4 行。
- 极矮横屏由 `@media (max-height:360px)` 收紧间距与字号，按钮最小边长约 52px。

## 5. 分页与页索引

- 两个区继续使用 `.pages` 横向 `scroll-snap-type: x mandatory`；每页 `flex: 0 0 100%`。
- `renderZone(pagesEl, dotsEl, items, cols, rows)` 负责分页、占位和页点。
- 重排前读取 `pageIndex = round(scrollLeft / clientWidth)`；重排后 `requestAnimationFrame` 恢复，并夹到 `pageCount - 1`。
- 旋转/窗口变化只重排，不强制回第一页。
- 页点可点击跳页；横向滑动时页点与滚动位置同步。
- 数据轮询刷新时，如果按钮 ID 列表未变化，不重排；只更新状态文本。

## 6. 原生 App 交互

```css
.pages { touch-action: pan-x; overscroll-behavior-x: contain; }
#pair { overflow-y: auto; -webkit-overflow-scrolling: touch; }
```

- 只允许横向手势滚动分页，纵向手势不滚动页面。
- `body` 锁视口，禁用整页滚动/回弹。
- 保留现有 `dblclick`、`gesturestart`、300ms 二次 `touchend` 拦截。
- 新增 `dragstart`、`contextmenu`、`selectstart` 拦截；`selectstart` 在 `input` 上放行，避免配对输入框无法选字。
- 不实现按钮拖拽排序。

## 7. JS 重构点

1. 把「绑定监听」从 `render()` 移出，放到 `init()` 一次绑定。
2. 新增 `layoutNow()`：读取方向、可用高度、列/行，更新 CSS 变量，调用 `renderZone`。
3. `render(buttons)` 只保存数据并调用 `layoutNow()`；数据未变化时跳过重建。
4. `window.resize`、`orientationchange`、`visualViewport.resize` 统一 debounce 80–200ms 调 `layoutNow()`。
5. 删除 `syncFooter()` 与 `--quick-h` 写入；快捷区由 flex 布局自然占位。
6. `renderZone` 支持 `kind`、`cols`、`rows`，按 `cols*rows` 分页；占位透明；页点点击可跳页。
7. 保持现有按钮队列、状态、toast、配对、健康检查逻辑不变。

## 8. 边界情况

- **0 个快捷操作**：隐藏 `#shortcutsZone`，应用区占满；不留空白标题。
- **1–7 个快捷操作**：仍显示 2 行（竖屏 4×2 / 横屏 2×4），空格透明占位；高度不跳动。
- **应用区不足一页**：只显示一页，隐藏页点。
- **极窄竖屏 320×568**：4 列快捷卡片约 70px 宽，字号 11px；应用 2 列；允许卡片高度低于 64px 但不低于 56px。
- **极矮横屏 568×320**：进入紧凑档；右栏 4 行、卡片约 52px；页点缩小；不允许裁切。
- **iPad/分屏**：宽度变化时按横屏/竖屏规则重算，不依赖设备型号。
- **配对页 + 键盘**：`#pair` 可纵向滚动；主面板仍锁定视口。
- **刘海/Home Indicator**：所有边距使用 `env(safe-area-inset-*)`；`toast` 底部避让安全区。

## 9. 验证方案

### 9.1 浏览器/设备

- Chrome DevTools 设备模拟：375×667、390×844、430×932、667×375、844×390、932×430、1440×900。
- 实际 iPhone Safari 至少验证竖屏与横屏各一次。
- 旋转 3 次，确认页索引保持、无空白/重叠。

### 9.2 断言

- `document.scrollingElement.scrollHeight === window.innerHeight`，页面无纵向滚动。
- 每个 `.btn` 的底边不超过所属 zone 的底边。
- 快捷区竖屏正好 2 行、横屏右栏正好 4 行；无第 3 行/第 5 行溢出。
- 12 个快捷操作：竖屏 2 页、横屏 2 页，页点同步。
- 横向滑动可翻页；纵向拖动 `window.scrollY` 保持 0。
- 长按不弹菜单；双击不缩放；按钮不可拖动。
- 配对页输入框可正常选字、键盘弹出不遮住按钮。

### 9.3 构建

- `swift test`
- `swift build -c release`
- `./Build/build.sh`
- `./Build/verify-signing.sh BuildOutput/MacAppControlDeck.app`
- 覆盖安装后 `./Build/verify-signing.sh /Applications/MacAppControlDeck.app`

## 10. 交付顺序

1. 静态预览页（`Docs/design/remote-panel-responsive/`）先确认视觉。
2. 修改 `PanelHTML.swift`，版本号改为 `2026-11-22.2`。
3. 本机/手机验收，截图归档。
4. 同步 `openspec/specs/remote-web-panel/spec.md`，归档变更。
