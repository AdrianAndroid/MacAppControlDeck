# Tasks

- [x] 复现：安装包内资源实际在 `.bundle/Contents/Resources/Sketch`，旧 `resourceRoot()` 只查 `.bundle/Sketch` 与 `Resources/Sketch` → 返回 nil
- [x] 重写 `resourceRoot()`：扫描 `Contents/Resources/*.bundle`，`Bundle(url:).url(forResource:)` + 三种路径兜底，统一用 `index.html` 判定
- [x] 新增 `UI/NonModalAlert`（浮动窗口、按钮自关，不用 `runModal()`）
- [x] `SketchWindowController.showAlert` 改用非模态提示
- [x] 校验：对 `/Applications/MacAppControlDeck.app` 跑同一套候选路径，`Contents/Resources/<bundle>/Contents/Resources/Sketch` 命中 `index.html`
- [x] 构建 + 固定签名覆盖安装
