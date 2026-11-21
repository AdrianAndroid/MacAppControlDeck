# 提案：UI 草图懒加载与释放

## Why

UI 草图当前虽然会在关闭窗口时销毁 `WKWebView`，但 `SketchWindowController.shared`、`SketchStore.shared` 和 `SketchModule.shared` 仍长期存在，窗口、控制器、画布索引与网页桥接对象的生命周期绑在进程上。用户希望和万年历一致：打开画板才加载，关闭窗口释放，只有电脑控制与截图保持常驻。

## What Changes

- 新增 `SketchRuntime`，由 `SketchModule` 按需创建并持有：
  - `SketchStore` 改为 runtime 实例，不再全局单例；
  - `SketchWindowController` 去掉 `shared`，改为 runtime 持有；
  - 关闭窗口后按「常驻内存」决定保留 runtime 或整体释放。
- `SketchModule` 保留为轻量代理：
  - 菜单、全局快捷键、内置操作、设置页都只调用代理；
  - 首次打开画板时创建 runtime；
  - 默认 `resident=false`，关闭窗口释放窗口、WebView、Bridge、BoardStore、Store；
  - `resident=true` 时关闭窗口仍保留轻量控制器与数据，但 WebView 仍然销毁（不保留网页进程）。
- 设置页增加「常驻内存」开关；模块卡片也显示同一开关。
- 测试改为使用 `SketchStore()` 实例，验证保存逻辑不依赖全局单例。

**非目标**：

- 不改变画板 UI、Excalidraw 版本、文件格式和保存目录。
- 不保活 WKWebView 网页进程；即使常驻，关闭窗口也释放网页。
- 不把 UI 草图搬到主窗口或手机面板。

## Capabilities

### New Capabilities

- `sketch-lazy-runtime`：UI 草图模块代理、按需 runtime、关闭释放、常驻内存开关。

## Impact

- 代码：`Modules/Sketch/SketchModule.swift`、`SketchWindowController.swift`、`SketchStore.swift`、`SketchSettings.swift`、`SketchSettingsView.swift`、`BuiltinActions.swift`。
- 测试：`SketchStoreTests` 改为实例化 Store；新增 runtime 生命周期不依赖全局单例的断言。
- 文档：README、`Docs/archive/2026-11-21-sketch-lazy-runtime/SUMMARY.md`。
- OpenSpec：新能力 `sketch-lazy-runtime`。
