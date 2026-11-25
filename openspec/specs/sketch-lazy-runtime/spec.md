# sketch-lazy-runtime 规格

## ADDED Requirements

### Requirement: 按需创建 UI 草图 runtime

UI 草图模块 SHALL 只保留轻量代理；窗口、WebView、桥接、Store 与 BoardStore SHALL 在首次打开画板时创建。

#### Scenario: 冷启动不加载画板

- **WHEN** 应用启动且用户未打开 UI 草图
- **THEN** 不创建 `SketchWindowController` 与 `WKWebView`
- **AND** 不创建 `SketchRuntime`

#### Scenario: 首次打开

- **WHEN** 用户点击「打开画板」、按 `⌃⌥D` 或执行 `sketch.open`
- **THEN** 创建 `SketchRuntime`、`SketchStore`、`SketchWindowController`
- **AND** 显示画板窗口

### Requirement: 关闭窗口释放

默认 `resident=false` 时，关闭画板窗口 SHALL 释放窗口、`WKWebView`、Bridge、BoardStore、Store 与 runtime。

#### Scenario: 默认关闭

- **WHEN** `resident=false` 且用户关闭画板窗口
- **THEN** 先落盘当前画布
- **AND** 销毁 WebView 与 runtime
- **AND** 再次打开时重新创建

#### Scenario: 常驻内存

- **WHEN** 用户开启「常驻内存」
- **THEN** 关闭窗口后保留轻量 `SketchWindowController` 与 `SketchStore`
- **AND** `WKWebView` 仍然销毁，不保留网页进程
- **AND** 关闭常驻且窗口已关闭时释放 runtime

### Requirement: 统一入口

菜单、全局快捷键、内置操作与设置页 SHALL 通过 `SketchModule` 代理打开画板。

#### Scenario: 从设置页打开

- **WHEN** 用户在 UI 草图设置页点击「打开画板」
- **THEN** 通过 `SketchModule.shared.openBoard()` 创建 runtime 并显示窗口

### Requirement: 画板静态资源定位

打开画板前 SHALL 解析出 Excalidraw 静态资源目录，并兼容 SwiftPM 生成的资源 bundle 布局；找不到时才提示，且不得进入阻塞模态。

#### Scenario: SwiftPM 资源 bundle

- **WHEN** 资源位于 `MacAppControlDeck.app/Contents/Resources/<Name>.bundle/Contents/Resources/Sketch`
- **THEN** 用该目录作为 `deck-sketch://` 的根，正常加载 `index.html`
- **AND** 不显示「资源缺失」提示

#### Scenario: 资源确实缺失

- **WHEN** 所有候选目录都没有 `index.html`
- **THEN** 用非模态浮动窗口提示「UI 草图资源缺失」
- **AND** 提示显示期间菜单栏、全局快捷键与截图仍然可用

### Requirement: 提示不得阻塞应用

模块内的提示 SHALL NOT 使用 `NSAlert.runModal()`。

#### Scenario: 提示期间仍可操作

- **WHEN** 任一模块提示窗显示
- **THEN** 应用不进入模态会话（`NSApp.modalWindow == nil`）
- **AND** 用户可以照常打开菜单栏、触发 F1 截图并截到该提示
