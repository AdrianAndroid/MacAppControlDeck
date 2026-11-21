# 技术设计：UI 草图懒加载

## 结构

```text
SketchModule（轻量代理，长期存在）
└── runtime: SketchRuntime?
      ├── SketchStore（草稿/导出/最近列表）
      ├── SketchWindowController（窗口 + WKWebView + Bridge）
      │     └── SketchBoardStore（多画布索引，懒加载）
      └── onClose → 根据 resident 释放
```

## 生命周期

```text
点击“打开画板” / ⌃⌥D / 内置操作
→ SketchModule.ensureRuntime()
→ SketchRuntime 创建 SketchStore + SketchWindowController
→ show()

关闭窗口
→ flushDraft + teardownAfterClose
→ onClose
→ resident=false：SketchModule.releaseRuntime()
→ runtime=nil，Store/Controller/BoardStore 释放
→ resident=true：保留 Controller/Store，WebView 已销毁
```

## 关键点

- `SketchWindowController` 不再有 `static shared`，避免窗口和 WebView 被进程级单例强引用。
- `SketchStore` 不再有 `static shared`；`SketchStoreTests` 直接 `SketchStore()`。
- `SketchModule.menuItems()` 读取最近草图时使用轻量静态查询，不创建 runtime。
- `SketchModule` 的菜单 action 全部转发到 runtime；runtime 不存在时按需创建。
- WebView 关闭时继续调用 `destroyWebView`，释放 `WKUserContentController`、`SketchBridge`、`SketchSchemeHandler`。
- 常驻开关只保留轻量对象，不保活 `WKWebView`，避免“常驻”变成高内存。

## 验收

- 默认非常驻：打开画板 → 关闭 → `SketchWindowController` / `SketchStore` 实例归零。
- 常驻：关闭后 `SketchWindowController` / `SketchStore` 保留，但 `WKWebView` 销毁。
- 再关闭常驻且窗口已关闭：runtime 释放。
- 反复打开/关闭 3 次，实例数不累积。
