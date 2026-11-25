# Change: 修复 UI 草图资源定位与阻塞式提示

## Why

打开 UI 草图会弹「UI 草图资源缺失」，画板打不开；而且这个提示是 `NSAlert.runModal()`，应用进入模态会话后菜单栏与全局快捷键全部失效，用户在提示显示期间连截图都做不到。

两个问题同源：定位资源的路径写死了老构建方式，提示方式又用了阻塞模态。

## What Changes

1. `SketchSchemeHandler.resourceRoot()` 不再拼固定 bundle 名，改为扫描 `Contents/Resources/*.bundle`：
   - `Bundle(url:).url(forResource: "Sketch")`（SwiftPM 资源 bundle 的正确入口，资源在 `.bundle/Contents/Resources/Sketch`）
   - `.bundle/Contents/Resources/Sketch`、`.bundle/Sketch`、`Resources/Sketch` 兜底
   - 统一用「该目录下是否有 `index.html`」判定
2. 新增 `UI/NonModalAlert`：用浮动窗口展示提示（`level = .floating`、按钮自己关窗），不再调用 `runModal()`。
3. `SketchWindowController.showAlert` 改走 `NonModalAlert`：提示显示时菜单栏、`F1` 截图与其它模块仍然可用，提示本身也能被截到。

## Capabilities

- `sketch-lazy-runtime`（修改）：新增资源定位与非阻塞提示的约束。

## Impact

- `Modules/Sketch/SketchSchemeHandler.swift`：`resourceRoot()` 重写。
- `Modules/Sketch/SketchWindowController.swift`：`showAlert` 改非模态。
- 新增 `UI/NonModalAlert.swift`。
- 不做数据迁移，不改画板内容与保存路径。

## Non-goals

- 不改 Excalidraw 前端资源与素材库。
- 不重做所有提示：截图模块里申请权限的模态弹窗保持原样（那是系统授权流程的一部分）。
