# UI 草图懒加载与释放（2026-11-21）

对应 OpenSpec 变更：[`add-sketch-lazy-runtime`](../../../openspec/changes/archive/2026-11-21-add-sketch-lazy-runtime/proposal.md)
能力规格：[`sketch-lazy-runtime`](../../../openspec/specs/sketch-lazy-runtime/spec.md)

## 需求

沿用万年历的懒加载模式，把 UI 草图从进程级单例改为按需加载：

- 只有打开画板、`⌃⌥D` 或内置操作 `sketch.open` 时才创建窗口、WebView、Store 与画布索引；
- 默认关闭窗口后释放 runtime，不让 `SketchModule` 长期持有重对象；
- 设置里提供「常驻内存」开关，开启后只保留轻量控制器与 Store，仍销毁 WebView；
- 菜单、全局快捷键、内置操作与设置页统一走 `SketchModule` 代理；
- 只有电脑控制与截图/录屏常驻。

## 实现

### 结构

```text
SketchModule（轻量代理，长期存在）
└── runtime: SketchRuntime?
      ├── SketchStore（草稿/导出/最近列表）
      └── SketchWindowController（窗口 + WKWebView + Bridge）
            └── SketchBoardStore（多画布索引，懒加载）
```

### 生命周期

- 新增 `SketchRuntime`，同时持有 `SketchStore` 与 `SketchWindowController`。
- `SketchModule` 只保存 `runtime: SketchRuntime?`，所有画板动作先 `ensureRuntime()`。
- `SketchWindowController` 移除 `static let shared`，改为 `init(store:)` 注入 Store；新增 `onClose` 与 `isWebViewLoaded`。
- 用户关闭窗口：`flushDraft()` → `teardownAfterClose()` → `onClose`。
  - `resident=false`：`DispatchQueue.main.async` 释放 runtime，避免在 delegate 回调里销毁自身。
  - `resident=true`：保留 Controller/Store，WebView 由 `destroyWebView()` 销毁。
- `SketchModule.stop()` / 关闭常驻且窗口已关闭时立即 `releaseRuntime()`。
- 程序化 `shutdown()` 不触发 `onClose`，避免释放路径递归。
- 菜单「最近草图」改用 `SketchStore.recentSketches()` 静态轻量查询，不创建 runtime。
- 「在 Finder 中显示上次保存」改用 `SketchStore.revealLastSaved()`，只读设置，不加载画板。

### 入口与设置

- `BuiltinActions` 的 `sketch.open` 改为 `SketchModule.shared.openBoard()`。
- `SketchSettingsView` 的「打开画板 / 新建画布 / 显示上次保存 / 窗口置顶」全部改走模块入口或 Store 静态方法。
- `SketchSettings` 新增 `sketch.resident`，默认 `false`。
- UI 草图设置页增加「常驻内存」开关、runtime 状态点与释放说明；模块页因 `supportsResidency = true` 同步出现同一开关。
- 设置页通过 `SketchModule.runtimeDidChange` 通知刷新 runtime 状态。

## 验证

- `swift test`：58 个测试全部通过；新增 `SketchRuntimeTests` 验证 runtime 释放后 Store/Controller 可被回收；`SketchStoreTests` 改为 `SketchStore()` 实例。
- `./Build/build.sh` release 构建、签名成功，产物 `BuildOutput/MacAppControlDeck.app`，覆盖安装到 `/Applications/MacAppControlDeck.app`。
- 实机验证：
  - 默认启动：`heap --addresses=SketchWindowController` / `SketchStore` 均为 0；
  - `⌃⌥D` 打开后：两者各 1 个；
  - 关闭窗口后：两者归零；
  - `resident=true` 启动即预创建，关闭窗口后仍保留 1 个 Controller/Store，窗口已消失；
  - 恢复 `resident=false` 重启后再次归零；
  - 连续打开/关闭 3 次，实例数不累积。

## 已知限制

- 常驻模式只保留轻量控制器与 Store，不保活 `WKWebView`；再次打开仍会重建网页并加载画板。
- 关闭窗口后业务对象可回收，但进程 RSS 不一定立即下降，这是 AppKit/WebKit 缓存与分配器行为。
- 未新增用户可见入口：沿用原有 `sketch.open`、菜单「打开画板」、`⌃⌥D` 与设置页按钮。
