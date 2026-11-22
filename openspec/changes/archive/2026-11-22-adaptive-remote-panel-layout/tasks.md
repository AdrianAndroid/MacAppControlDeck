# 任务清单：adaptive-remote-panel-layout

## 0. 预览与确认

- [x] 0.1 输出竖屏/横屏 ASCII 布局与需求讨论稿
- [x] 0.2 生成可交互的静态预览页，覆盖 390×844、844×390、375×667、667×375
- [x] 0.3 用户确认预览视觉与布局口径（含横屏右侧方形按钮）

## 1. 布局重构

- [x] 1.1 根容器锁定视口：`position:fixed`、`overflow:hidden`、`overscroll-behavior:none`
- [x] 1.2 移除 `#shortcutsZone` 的 `position:fixed` 与 `--quick-h` 高度预留
- [x] 1.3 竖屏改为上下双区：应用 2 列动态行，快捷 4×2
- [x] 1.4 横屏改为左右双栏：应用 4 列；快捷 2×4 方形，右栏宽度按 4 行方形按钮反推
- [x] 1.5 宽屏窗口限制最大宽度 1280px 并居中
- [x] 1.6 新增 `--u`、`--gap`、卡片/图标/字号 `clamp()` 变量
- [x] 1.7 新增 `@media (max-height:360px)` 紧凑档

## 2. JS 布局引擎

- [x] 2.1 新增 `layoutNow()`：方向、列数、动态行数、CSS 变量、重新分页
- [x] 2.2 应用区行数按实测高度计算：竖屏 2–6 行、横屏 2–4 行
- [x] 2.3 快捷区固定行数：竖屏 2 行、横屏 4 行
- [x] 2.4 `renderZone` 支持 `cols/rows`、透明占位、页点点击跳页
- [x] 2.5 重排前记录页索引，重排后恢复并夹到最后一页
- [x] 2.6 监听 `resize`、`orientationchange`、`visualViewport.resize`，统一 debounce
- [x] 2.7 移除 `render()` 内重复绑定监听
- [x] 2.8 数据轮询未变化时只更新状态，不重建网格

## 3. 原生交互

- [x] 3.1 `.pages` 使用 `touch-action:pan-x`，禁止纵向滚动
- [x] 3.2 拦截 `dragstart`、`contextmenu`、`selectstart`（输入框放行）
- [x] 3.3 保留双击缩放、长按菜单、二次 `touchend` 拦截
- [x] 3.4 配对页 `#pair` 允许纵向滚动，键盘弹出不遮按钮
- [x] 3.5 安全区、`toast` 底部避让保持有效

## 4. 版本与文档

- [x] 4.1 `PanelHTML.version` 改为 `2026-11-22.2`
- [x] 4.2 更新 `Docs/plans/2026-11-22-remote-panel-responsive.md` 为已确认版本
- [x] 4.3 预览截图放入 `Docs/design/remote-panel-responsive/`
- [x] 4.4 同步 `openspec/specs/remote-web-panel/spec.md`

## 5. 验证

- [x] 5.1 375×667 竖屏：快捷 4×2，应用 2 列，5 行
- [x] 5.2 390×844 竖屏：快捷 4×2，应用 2 列，6 行，页点正常
- [x] 5.3 667×375 横屏：右栏 2×4 方形约 66.97px，无裁切
- [x] 5.4 844×390 横屏：左应用 4 列 / 右快捷 2×4 方形 70.19px，8 个/页
- [x] 5.5 932×430、1440×900：宽屏分栏与最大宽度生效
- [x] 5.6 旋转 3 次：页索引保持，无空白/重叠
- [x] 5.7 0/1/7/8/12 个快捷操作：布局不塌陷，分页正确
- [x] 5.8 横向滑动翻页、页点同步；页点可点击跳页
- [ ] 5.9 长按/双击/拖动被禁用；配对页输入正常
      - 已用 Chrome CDP 验证触控/页点；本机没有真实 iPhone，Safari 手测留到 v0.3.1 真机回归
- [ ] 5.10 `swift test`、`swift build -c release`、`./Build/build.sh` 通过
      - `swift build -c release` 与 `./Build/build.sh` 已通过
      - `swift test` 111 个用例中 109 个通过；2 个 `PetPanelControllerTests` 尺寸断言失败，与面板改动无关
- [x] 5.11 覆盖安装后 `./Build/verify-signing.sh` 校验通过
      - `BuildOutput/MacAppControlDeck.app` 与 `/Applications/MacAppControlDeck.app` 均通过稳定签名校验
      - 已安装面板 `/panel` 返回版本 `2026-11-22.2`

## 6. 归档

- [x] 6.1 变更归档到 `openspec/changes/archive/2026-11-22-adaptive-remote-panel-layout/`
- [ ] 6.2 提交说明引用 `adaptive-remote-panel-layout`
- [x] 6.3 确认无新增模块/窗口，无需新增内置打开按钮
