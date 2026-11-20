# 2026-11-20 · 截图模块与 macshot 体验对齐总结

## 目标

在已完成的 macshot 能力移植基础上，把**区域截图的交互机制**做成与上游一致：工具条围绕选区、Retina 像素正确、打开即响应、权限与热键不再误报/失效、钉图 Esc 可关闭。

对照基线：本机已安装 macshot Offline 4.4.0 + 上游源码 HEAD 4.5.0-beta.2。

## 直接搬运的代码

| 上游 | 本仓库 | 内容 |
|---|---|---|
| `UI/Toolbar/ToolbarButtonView.swift` | `CaptureToolbarButtonView` | 32pt 方块、悬停/按下/选中态、色板、SF Symbol 着色 |
| `UI/Toolbar/ToolbarStripView.swift` | `CaptureToolbarStripView` | 4pt 内边距、2pt 间距、6pt 圆角、横/纵布局 |
| `UI/Toolbar/ToolbarDefinitions.swift#ToolbarLayout` | `ToolbarLayout` | 紫色强调色、白色图标、`white 0.12` 背景 |
| `OverlayView.repositionToolbars()` | `SelectionView.layoutToolbars()` | 工具条围绕选区的完整几何规则 |

最终布局：

- 横向工具条：选区下方 6pt、水平居中；
- 选项行（线宽 2/4/8、线型 实/虚/点）：工具条下方 2pt；
- 竖向动作栏（保存/复制/钉图/OCR/关闭）：选区右侧 6pt、与选区顶对齐；
- 空间不足时按上游优先级换边/换位置。

## 关键问题与修复

### 1. 工具条“飞到边上”和黑色色块

之前是照着截图手绘工具条（大块黑色圆角面板 + 文字按钮），位置固定在屏幕边缘。改为搬运上游 NSView 工具条后，位置、材质、按钮状态都与 macshot 对齐，大黑块消失。

### 2. Retina 尺寸错误

- 选区快照按 1x 合成，背景发虚、尺寸显示为点；
- 导出时 `NSImage.lockFocus` 在 2x 屏二次放大，保存成 2400×1440。

修复：多屏拼接按 `backingScaleFactor` 输出；W×H 显示/提交物理像素；导出改用显式像素 `NSBitmapImageRep`。实测 600×360 pt 选区 → 显示并保存 1200×720，与 macshot 一致。

### 3. 打开延迟

- 打开时同步抓整屏（2x 约 4112×2658）；
- 每次鼠标移动都 `NSBitmapImageRep(cgImage:)` 重建整张位图做吸附。

修复：遮罩先显示、后台抓帧回填（抓帧期间自身窗口 `sharingType = .none`，完成后恢复）；吸附检测缓存位图；拖动时只移动工具条 frame。

### 4. 授权了仍反复提示 / 偶发卡死

根因是自加的“抓其他应用窗口”权限探针：未授权时会阻塞在 TCC IPC，卡住主线程（表现为热键、Esc 全部失效）。同时 `CGPreflightScreenCaptureAccess()` 在重签名后会误报 false。

修复：删除探针；不再用预检阻断流程，只有真实抓图失败才提示；提示文案补充“旧签名条目需删除后重新添加”。

### 5. 重建后热键失效

macshot 与 `MacAppControlDeck` 默认都注册 ⌘⇧X，后启动者注册失败且不会重试。修复：记录失败的绑定，每 2 秒重试。

### 6. 固定签名

`setup-signing.sh` 创建自签名证书；`build.sh` 改为优先使用任何有效的 `MacAppControlDeck*` 身份（`Dev` 或 `Self-Signed`）。此后重建不再需要重新授权。

### 7. 钉图 Esc

上游/此前行为：必须先点击钉图（成为 key window）再按 Esc。按用户预期改为：

- 点击钉图 `makeKey` + 成为 first responder；
- 全局/本地 Esc 监听：鼠标悬停在钉图上即可关闭；不拦截其他应用的 Esc；
- 关闭最后一张钉图后移除监听。

## 同批补齐的体验（详见 `Docs/architecture/MACSHOT_PORT.md`）

- 文件名模板、快门音、保存开关真正生效、悬浮缩略图、缩略图网格历史、钉剪贴板内容、OCR 语言切换；
- 选区尺寸框/三分网格/窗口悬停高亮；直线/荧光笔/线型/Shift 约束/画笔平滑/字体/测量校准/不透明度；
- 滚动截图到底检测 + HUD + 固定侧栏；录屏真实帧时序 + 磁盘/休眠保护 + 倒计时；
- 视频编辑器多段剪切/变速/字幕/进度取消/GIF 导出。

## 验证

- `swift build`、`./Build/build.sh` 通过；`swift test` 42 项，2 个既有 `/panel/` 断言失败（与本模块无关）。
- 对照 macshot：同一拖选两边均显示 1200×720。
- 区域截图 → 快捷键 2 切矩形 → 画红框 → Enter 保存 1200×720，工具条/遮罩未被烘焙。
- 钉图：窗口列表确认 600×360 面板创建；鼠标移上去按 Esc 后面板消失。
- 巡检：遮罩打开即出现（无需等待整屏抓图）。

## 未移植（保持原有边界）

账号/登录、Sparkle、上传、在线翻译、PII 自动打码、可编辑光标/按键 HUD/摄像头画中画、视频缩放/定格/打码轨道、自定义图片印章。

## 反思

第一轮选择了“看截图仿制”，导致位置、材质、Retina 语义全部偏差，返工成本高。结论：**有上游源码时，优先搬运其 UI 组件与布局算法，再补业务适配**，不要先自创一套再逐项对齐。

## 相关文件

- 覆盖层：`Sources/MacShotKit/AreaSelectionController.swift`、`CaptureToolbar.swift`
- 抓图：`Sources/MacShotKit/ScreenCaptureService.swift`
- 权限/热键：`Sources/MacShotKit/MacShotController.swift`、`Sources/MacAppControlDeck/App/GlobalHotKeys.swift`
- 钉图：`Sources/MacShotKit/PinWindowController.swift`
- 构建：`Build/build.sh`、`Build/setup-signing.sh`
- OpenSpec：`openspec/changes/archive/2026-11-20-capture-parity-and-experience/`、`openspec/specs/capture-overlay-parity/spec.md`
