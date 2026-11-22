# 手机面板横竖屏自适应 · 实施总结

日期：2026-11-22

## 结果

手机面板从「竖屏 4×3、横屏底部 6×2」改为按视口方向自动换布局：

- 竖屏：应用 2 列动态行 + 底部快捷 4×2，每页 8 个快捷按钮
- 横屏：应用 4 列 + 右侧快捷 2×4 方形按钮，右栏宽度由 4 行方形按钮反推
- 根容器锁定视口，禁止纵向滚动与回弹，只保留横向 scroll-snap 和页点跳页
- 旋转/窗口变化后保持应用页与快捷页索引，页数不足时夹到最后一页
- 宽度 < 360px 的极矮横屏进入紧凑档；宽屏最大宽度 1280px 居中

生产版本号：`PanelHTML.version = 2026-11-22.2`。

## 验证

- Chrome CDP 真实视口：375×667、390×844、667×375、844×390、932×430、1440×900、320×568、568×320 均无页面溢出
- 横屏方形按钮实测 66.97 / 70.19 / 79.44 / 196px（667×375 / 844×390 / 932×430 / 1440×900）
- 旋转 3 次页索引保持；0/1/7/8/12 个快捷操作分别验证隐藏、占位与分页
- `swift build -c release`、`./Build/build.sh`、固定签名校验、覆盖安装与 `/api/panel-version` 通过
- `swift test` 111 项中 109 通过；2 个 `PetPanelControllerTests` 窗口尺寸断言失败，与本次面板改动无关

## 未完成与后续

- 真实 iPhone Safari 的长按/双击/拖动与配对页键盘手测尚未执行，留到 v0.3.1 真机回归
- 真机实测截图：`Docs/design/remote-panel-responsive/panel-actual-portrait.png`、`panel-actual-landscape.png`、`panel-actual-compact-landscape.png`

## 链接

- OpenSpec：`openspec/changes/archive/2026-11-22-adaptive-remote-panel-layout/`
- 能力规格：`openspec/specs/remote-web-panel/spec.md`
- 实施记录：`Docs/plans/2026-11-22-remote-panel-responsive.md`
