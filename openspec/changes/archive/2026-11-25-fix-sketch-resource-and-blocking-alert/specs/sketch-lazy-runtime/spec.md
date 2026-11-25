# sketch-lazy-runtime Delta

## ADDED Requirements

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
