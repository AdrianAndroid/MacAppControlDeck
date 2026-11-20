# UI 草图（手写板）模块集成计划

> 日期：2026-11-20  
> 状态：**已完成并安装验证（2026-11-20）**  
> 目标版本：MacAppControlDeck 0.1.0 功能增量（不自动发布新 Release）  
> 方案：Excalidraw 0.18.1 + WKWebView，新增独立 `sketch` 模块

## 1. 目标

在菜单栏应用内新增一个“UI 草图”画板：

1. 用鼠标/触控板绘制 UI 意图：手绘、矩形、箭头、文字、便签。
2. 可以粘贴现有截图作为底图，在截图上圈注。
3. 一键把画板或选中对象导出为 PNG 写入系统剪贴板，直接粘贴给 AI。
4. 保存到本地：PNG + `.excalidraw` 源文件。
5. 自动保存草稿，关闭再打开恢复上次内容。
6. 完全离线，不访问 Excalidraw 云服务、不加载 CDN。
7. 不修改 `remote`、`capture` 模块的行为和数据。

## 2. 已定产品决策

| 项目 | 决策 |
| --- | --- |
| 模块 ID / 名称 | `sketch` / “UI 草图” |
| 画板模型 | 单一当前画板 + 自动草稿；多画板留到后续 |
| 保存位置 | 默认 `~/Pictures/MacAppControlDeck/Sketches`，可在设置修改 |
| 导出格式 | PNG（默认白底、2 倍、最长边 ≤ 3000 px）+ `.excalidraw` |
| 复制范围 | 有选中元素时只复制选中；无选中复制全部 |
| 窗口 | 1100×760，记住位置；提供“窗口置顶”开关 |
| 全局快捷键 | `⌃⌥D` 打开画板 |
| 默认置顶 | 仅全新安装把“打开 UI 草图”加入默认置顶 |
| 中文字体 | 首版不打包 12 MB 的小赖字体；中文回退系统字体 |
| 网络 | 页面内所有 http/https 请求拦截；外部链接交给默认浏览器 |
| 分发 | 本次只构建、覆盖安装、测试、归档；不自动发布 GitHub Release |

## 3. 架构

```
Sources/MacAppControlDeck/Modules/Sketch/
  SketchModule.swift              FeatureModule：启停、菜单、快捷键入口
  SketchWindowController.swift    NSWindow + WKWebView 生命周期
  SketchBridge.swift              WKScriptMessageHandler + callAsyncJavaScript
  SketchSchemeHandler.swift       deck-sketch:// 静态资源服务
  SketchStore.swift               草稿、保存、目录、命名、设置
  SketchSettingsView.swift        模块设置页
  Resources/Sketch/               构建产物（SwiftPM .copy 资源）
Web/sketch/
  src/main.jsx                    React 包装层 + window.deckSketch
  package.json / package-lock.json
  vite.config.ts
  scripts/copy-fonts.mjs
Build/build-sketch-web.sh         npm ci + vite build + 字体复制
```

注册点：`App/DeckApp.swift` 增加 `ModuleRegistry.shared.register(SketchModule.shared)`。

数据隔离：

```
~/Library/Application Support/MacAppControlDeck/Sketch/draft.excalidraw
UserDefaults 前缀：sketch.
```

## 4. 资源与离线策略

- Vite `base: "/"`，通过 `deck-sketch://local/index.html` 加载。
- `WKURLSchemeHandler` 只服务 `Resources/Sketch` 内文件，拒绝路径穿越。
- 打包字体：Assistant、Excalifont、Virgil、Cascadia、Comic Shanns、Nunito、Lilita、Liberation，共约 0.42 MB。
- 不打包 Xiaolai（12 MB）；中文由系统字体回退。
- 不打包 Mermaid / KaTeX / AI / 协作模块。
- 禁用 Excalidraw 的导出弹窗、加载场景、保存到活动文件、主题切换、分享和嵌入网络内容。
- 注入 CSP，并用 `WKContentRuleList` 阻断 `http/https`。
- SwiftPM 资源 bundle 必须由 `Build/build.sh`、`Build/package-release.sh` 一起复制进 `.app/Contents/Resources`。

预计资源 4.8–5.0 MB，安装包从 10.4 MB 增到约 15.4 MB。

## 5. 桥接协议

JS 暴露：

```js
window.deckSketch = {
  getScene(): string,
  loadScene(json): void,
  exportPNG(scale, padding, background): Promise<{base64,width,height}>,
  showToast(text): void,
  clear(): void
}
```

Swift 使用 `callAsyncJavaScript` 直接 await JS Promise。

事件：

- JS → Swift：`ready`、`change`（1 秒防抖自动草稿）、`copyRequested`、`saveRequested`。
- Swift → JS：加载草稿、导出 PNG、显示 toast、清空。

复制流程：

1. 用户点右上角“复制图片”或菜单命令。
2. Swift 调 `exportPNG`；JS 判断 `selectedElementIds`。
3. 导出时自动裁掉空白、24 px padding、白底、2×。
4. Swift 解码 base64，写 `NSPasteboard` 的 PNG/TIFF。
5. JS 显示“已复制，可直接粘贴给 AI”。

保存流程：

1. 调 `getScene` 拿 `.excalidraw` JSON。
2. 调 `exportPNG` 拿 PNG。
3. 写入 `UI-Sketch-YYYY-MM-DD-HHmmss.png` 与同名 `.excalidraw`。
4. 原子写草稿，更新“最近保存”路径。

## 6. 窗口与菜单

菜单：

```
UI 草图
├── 打开画板              ⌃⌥D
├── 新建画板
├── 复制当前草图          ⌘⇧C（窗口内）
├── 保存                  ⌘S（窗口内）
├── 最近草图
├── 在 Finder 中显示
└── UI 草图设置…
```

窗口：

- `NSWindow` 普通窗口，`isReleasedWhenClosed = false`。
- 关闭时先 `orderOut`，flush 草稿后销毁 WKWebView，释放内存。
- 重开时重新加载草稿，约数百毫秒。
- `⌘S` 保存、`⌘⇧C` 复制、`⌘N` 新建；由 JS keydown 捕获后通知原生。
- 右上角两个自定义按钮：“复制图片”“保存”。

设置页：

- 保存目录（选择/恢复默认）
- 导出倍率 1× / 2× / 3×
- 背景 白色 / 透明
- 窗口置顶
- 全局快捷键展示（首版固定）
- 清空草稿

## 7. 分阶段执行

### Phase 0：技术验证（不改正式功能）

1. 用现有 `/tmp/excal-size-test` 构建带字体的离线包。
2. 新建最小 Swift WKWebView 测试程序，验证：
   - 自定义 scheme 加载 Vite 产物；
   - Excalidraw 正常渲染、字体加载；
   - 画矩形/文字后导出 PNG；
   - PNG 写剪贴板后能在预览/文本编辑中粘贴；
   - 断网无外部请求。
3. 记录耗时、体积、内存。
4. 若自定义 scheme 不可行，回退 `loadFileURL` + `base: "./"` + localStorage shim。

**Go/No-Go：** 离线渲染、导出、剪贴板三项全部通过才进入 Phase 1。

### Phase 1：Web 包装层

1. 建 `Web/sketch`，固定 `@excalidraw/excalidraw@0.18.1`。
2. 实现 `main.jsx`、顶部按钮、toast、快捷键、导出/加载 API。
3. 配置 Vite：禁用 Mermaid、复制字体、输出到 `Modules/Sketch/Resources/Sketch`。
4. 生成离线构建，检查资源清单和外部 URL。
5. 提交源码、lockfile 和构建产物（保证无 Node 环境也能 `swift build`）。

### Phase 2：原生模块

1. `SketchModule` 实现 `FeatureModule`。
2. `SketchSchemeHandler` + `SketchBridge` + `SketchWindowController`。
3. 草稿自动保存/恢复、关闭释放、窗口 frame 记忆。
4. 菜单、全局快捷键、模块开关。
5. 设置页与目录选择。
6. 更新 `Package.swift`、两个打包脚本复制资源 bundle。

### Phase 3：复制、保存与体验

1. 整板/选中导出。
2. 剪贴板 PNG + TIFF。
3. 保存 PNG + `.excalidraw`。
4. 最近草图菜单、Finder 定位。
5. 空画板提示、错误提示、导出中状态。
6. 窗口置顶。

### Phase 4：验证与归档

1. `swift test` 全量 + 新增单测。
2. `./Build/build.sh` release 构建，覆盖安装 `/Applications`。
3. 冒烟：打开、绘制、复制、粘贴、保存、重开恢复、离线。
4. `./Build/package-release.sh arm64` / `x86_64` 验证资源是否进入包。
5. 截图存档：菜单、画板、复制结果、保存文件、设置页。
6. 更新 README、`Docs/architecture/MODULES.md`、`THIRD_PARTY_NOTICES.md`。
7. 新增 `Docs/archive/2026-11-20-sketch-module/SUMMARY.md`。
8. 提交到本地 git；不自动触发 GitHub Release。

## 8. 验收标准

- [ ] 菜单栏出现“UI 草图”，可开关模块。
- [ ] `⌃⌥D` 在任意应用前台时能打开画板。
- [ ] 断网状态下画板完整加载，无 http/https 请求。
- [ ] 鼠标可手绘、画矩形/箭头、输入中英文。
- [ ] 可粘贴本地截图作为底图。
- [ ] 无选中时复制整板；有选中时只复制选中。
- [ ] 复制出的 PNG 白底、清晰、空白裁掉，可直接粘贴到聊天输入框。
- [ ] 保存生成同名 PNG 与 `.excalidraw`。
- [ ] 关闭再打开恢复上次草稿。
- [ ] 清空/新建后旧草稿按确认逻辑处理，不误删已保存文件。
- [ ] `swift test` 全部通过。
- [ ] arm64 / x86_64 包均包含 Sketch 资源并通过签名校验。
- [ ] App 体积在 16 MB 以内。
- [ ] 关闭 sketch 不影响 remote/capture；关闭 remote/capture 不影响 sketch。
- [ ] 不出现 Excalidraw 云端、协作、Mermaid、AI 入口。

## 9. 风险与回退

| 风险 | 回退 |
| --- | --- |
| 自定义 scheme 下 localStorage/crypto 异常 | 改 `loadFileURL` + `base: "./"`，注入 localStorage 内存 shim |
| JS 导出大图导致桥接慢 | 限制最长边 3000 px；必要时分块传 base64 或临时文件 |
| 资源 bundle 未进 `.app` | 打包后断言 `Contents/Resources/*.bundle/Sketch/index.html` 存在 |
| 字体缺失导致中文异常 | 使用系统字体回退；后续再裁剪小赖常用字子集 |
| WKWebView 内存占用 | 关闭窗口即销毁 webview；懒加载，不常驻 |
| Xcode/SwiftPM 资源签名问题 | `codesign --deep` 复验；资源 bundle 不包含可执行文件 |

## 10. 明确不做

- 多人协作、云同步、账号
- AI 生图 / 文生图
- 手机端草图入口
- 多画板库、模板市场
- 小赖中文手写字体完整打包
- 自动发布 GitHub Release


## 11. 执行结果（2026-11-20）

- Phase 0 验证通过；Phase 1–3 已实现；Phase 4 已完成编译、44 项单测、实机复制/保存/恢复测试。
- 新增 4 项 `SketchStoreTests`，覆盖 PNG + 源文件落盘、重名不覆盖、空画板、非法 PNG。
- 实机结果：复制 496×496 PNG（14,512 B）；保存同名 PNG + `.excalidraw`；关闭重开草稿恢复。
- 打包：`Build/build.sh` / `package-release.sh` 已复制 SwiftPM 资源 bundle；App 体积约 16 MB。
- 归档：`Docs/archive/2026-11-20-sketch-module/SUMMARY.md`。

## 12. 追加：复制 JSON（2026-11-20）

- 顶栏在「复制图片」与「保存」之间新增「复制 JSON」按钮，事件 `jsonCopyRequested`。
- 输出为纯文本 `NSPasteboardTypeString`，顶层 `isDiagram=true`、`diagramType="ui-sketch"`，`ai` 对象显式说明“这是一个图形/示意图”，并附 `howToRead`、`selectedOnly`。
- 附带 `summary`（元素数、类型统计、文字、边界、是否含图片）与完整 `scene`；不内嵌 PNG base64，位图仍走「复制图片」。
- 实机验证：整板 5 个矩形 → 5,402 B JSON；选中 1 个矩形 → `selectedOnly=true`、1 个元素、2,411 B；剪贴板为纯文本。

## 13. 追加：多画布切换（2026-11-20）

- 新增 `SketchBoardStore`：`Boards/index.json` + 每画布独立 `<uuid>.excalidraw`，首次启动把旧 `draft.excalidraw` 迁移为「画布 1」。
- Web 左上角新增「画布」下拉：列表、元素数、修改时间、新建、重命名、删除确认；有选中属性面板时自动收起避让。
- 切换时保存当前场景与视口，再加载目标场景并 `history.clear()`；180ms 柔和遮罩 + 中心 spinner 过渡。
- 原生桥接新增 `boardSwitchRequested` / `boardCreateRequested` / `boardRenameRequested` / `boardDeleteRequested`。
- 菜单「新建画板」改为「新建画布」，「最近草图」导入时创建独立画布，不再覆盖当前画布。
- 实机验证：迁移 5 元素旧草稿、新建/重命名/删除、跨画布切换、重启恢复上次画布、复制 JSON 仍为 5 元素。
