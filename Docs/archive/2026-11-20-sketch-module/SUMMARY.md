# UI 草图模块（2026-11-20）

## 目标

在 `MacAppControlDeck` 中加入一个纯本机的 UI 草图模块：鼠标画界面意图，画完直接把图形复制到剪贴板，粘贴给 AI 理解界面设计；同时保留可继续编辑的源文件。

## 最终方案

- **画板**：Excalidraw `0.18.1`，React `18.3.1`，Vite 构建为离线静态资源。
- **容器**：`WKWebView` + 自定义 scheme `deck-sketch://local/index.html`。
- **模块**：新增第三个独立模块 `sketch`，不改 `remote` / `capture`。
- **入口**：菜单栏「UI 草图」与全局快捷键 `⌃⌥D`。
- **导出**：有选中复制选中，无选中复制整板；PNG 白底/透明、1×/2×/3×、24 px padding、最长边 3000 px。
- **保存**：同名 PNG + `.excalidraw` 源文件；默认 `~/Pictures/MacAppControlDeck/Sketches`。
- **草稿**：`~/Library/Application Support/MacAppControlDeck/Sketch/draft.excalidraw`，输入后 1 秒防抖自动保存。

## 体积与字体

- 离线资源 `Resources/Sketch`：约 **4.9 MB / 77 文件**。
- 字体：**25 个文件 / 429.3 KB**，包含 Assistant、Excalifont、Virgil、Cascadia Code、Comic Shanns、Nunito、Lilita One、Liberation Sans。
- **不打包 Xiaolai 小赖中文手写体**：完整字体 12.07 MB / 209 文件，首版收益不高；中文回退系统苹方，英文/UI 文案用 Excalifont。
- 最终 App 约 **16 MB**（集成前约 10.4 MB）。

## 关键实现

| 文件 | 职责 |
|---|---|
| `Web/sketch/src/main.jsx` | Excalidraw 包装、选区导出、草稿、顶部按钮、快捷键 |
| `Web/sketch/scripts/copy-fonts.mjs` | 复制字体，跳过 Xiaolai |
| `Modules/Sketch/SketchWindowController.swift` | 窗口、WKWebView、导出/复制/保存/新建/最近草图 |
| `Modules/Sketch/SketchSchemeHandler.swift` | `deck-sketch` 资源加载、路径穿越保护、MIME |
| `Modules/Sketch/SketchBridge.swift` | JS → 原生事件（ready/change/copy/save/new） |
| `Modules/Sketch/SketchStore.swift` | 草稿、PNG + 源文件、剪贴板、最近列表 |
| `Modules/Sketch/SketchSettings.swift` | `sketch.` 前缀偏好、导出倍率/背景、窗口置顶 |
| `Modules/Sketch/SketchSettingsView.swift` | 设置页：目录、导出、窗口、离线说明 |
| `Modules/Sketch/SketchModule.swift` | 模块契约、菜单、快捷键、生命周期 |

## 实机踩坑与修复

1. **SwiftPM 资源 bundle 路径**
   - `Bundle.module` 生成的访问器默认查找 `.app` 根目录，而打包脚本把 bundle 放进 `Contents/Resources`。
   - 改为在 `SketchSchemeHandler` 中显式查找 `Contents/Resources/MacAppControlDeck_MacAppControlDeck.bundle/Sketch`，并在 `build.sh` / `package-release.sh` 中复制 SwiftPM bundle。

2. **`WKWebView.callAsyncJavaScript` 返回值不可靠**
   - 直接 `return window.deckSketch.getScene()` 得到 `Void`，布尔/对象结果也有桥接问题。
   - 改用 `evaluateJavaScript` 读取场景字符串；异步 PNG 导出改为“启动 Promise + 轮询 `window.__deckExport` JSON”，避免 SDK 返回值限制。
   - `evaluateJavaScript` 的启动脚本末尾必须返回受支持类型（`true`），否则报 `WKErrorDomain Code=5`。

3. **Optional 双层包装**
   - `callJS` 返回 `Any?`，直接 `value as? String` 会失败；统一改为 `guard let value, let ... = value as? ...`。

4. **画板误判为空**
   - 早期用 `Bool` 接收 JS 布尔值失败，导致复制时报 `emptyBoard`。
   - 改为读取场景 JSON 的 `elements.count`，彻底绕开布尔桥接。

5. **按钮换行**
   - 顶部“复制图片 / 保存”曾竖排换行；`sketch.css` 增加 `width: max-content`、`white-space: nowrap`、`flex: 0 0 auto` 后修复。

## 验证结果

- `swift test`：**44 项通过，0 失败**（新增 4 项 SketchStore 测试）。
- 实机：
  - 画矩形成功，工具栏/属性面板正常。
  - 复制整板：**496×496 PNG，14,512 字节**；剪贴板包含 `PNG` 与 `TIFF`。
  - 选中全部后复制：`selected=true`，导出成功。
  - 保存：生成 `UI-Sketch-2026-11-20-230443.png`（14 KB）与同名 `.excalidraw`（925 B）。
  - 关闭重开：草稿恢复，矩形仍在。
  - 页面无外部 http/https 资源请求；`deck-sketch` scheme 加载正常。

## 提交与产物

- 代码提交：`5b8effe feat(sketch): add offline Excalidraw whiteboard with clipboard export`
- 已覆盖安装：`/Applications/MacAppControlDeck.app`
- 双架构包：
  - `BuildOutput/release/x86_64/MacAppControlDeck-0.1.0-x86_64.dmg`
  - `BuildOutput/release/arm64/MacAppControlDeck-0.1.0-arm64.dmg`

## 验收截图

- `sketch-board.png`：画板与手绘矩形。
- `export-sample.png`：导出的白底 PNG。

## 已知限制 / 后续

- 首版只有单一当前画板 + 自动草稿；多画板/画板列表留后续。
- 未打包中文手写字体；若需要中文手写风，可裁剪常用汉字子集，预计增加 2–4 MB。
- 菜单“最近草图”当前只在画板内打开 `.excalidraw`，尚未做独立管理窗口。
- 本次未发布新的 GitHub Release；上一版 `v0.1.0` 的双架构 Release 保持不变。
