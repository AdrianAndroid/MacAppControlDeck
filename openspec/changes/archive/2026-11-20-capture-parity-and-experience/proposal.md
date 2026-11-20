# 提案：截图模块与 macshot 的体验对齐

## Why

上游 macshot 的截图/录屏能力已按能力清单移植，但实际体验与 macshot 差距明显：

- 区域截图的工具条是自绘的大块黑色面板，位置固定在屏幕边缘，与选区脱节；
- 选区快照按 1x 合成，Retina 屏上背景发虚、尺寸按点显示，保存结果与 macshot 不一致；
- 打开选区时同步抓取整屏，鼠标移动时反复重建位图做吸附，操作明显延迟；
- 授权后仍反复提示「需要屏幕录制权限」，偶发主线程卡死导致热键失效；
- 钉住的图片必须先点击才能按 Esc 关闭。

这些问题不涉及新能力，而是**交互机制和实现质量**问题。目标：以 macshot 源码为准，搬运其覆盖层工具条与布局算法，修正抓图/权限/性能链路，使区域截图的操作手感与结果对齐。

## What Changes

- **工具条搬运**：新增 `CaptureToolbar.swift`，移植 `ToolbarStripView`、`ToolbarButtonView`、`ToolbarLayout`；`SelectionView` 改用真实 NSView 工具条。
- **布局算法搬运**：移植 `OverlayView.repositionToolbars()` 的几何规则：
  - 横向工具条在选区下方居中（6pt 间距）；
  - 选项行（线宽/线型）在工具条下方（2pt）；
  - 竖向动作栏在选区右侧 6pt、与选区顶部对齐，空间不足时按上游规则推到左侧或下方。
- **Retina 正确性**：多屏拼接快照按 `backingScaleFactor` 输出；W×H 显示与输入按像素；导出使用显式像素 bitmap，避免 `lockFocus` 二次放大。
- **性能**：遮罩先显示、后台抓取冻结帧（抓帧期间自身窗口 `sharingType = .none`，完成后恢复）；吸附检测缓存 `NSBitmapImageRep`；工具条位置更新不再重建整张位图。
- **权限**：移除会被 TCC 阻塞的窗口抓取探针；不再用 `CGPreflightScreenCaptureAccess` 阻断流程，只在真实抓图失败时提示；构建脚本优先使用本仓库任何有效自签名身份。
- **热键**：注册失败（被其他截图工具占用）时每 2 秒重试。
- **钉图**：点击即成为 key window；鼠标停在钉图上按 Esc 即可关闭（全局监听仅在该钉图上生效）。
- 顺带补齐此前提到的保存体验：文件名模板、快门音、悬浮缩略图、缩略图网格历史、剪贴板钉图、OCR 语言切换、滚动截图到底检测与固定侧栏、录屏真实帧时序、视频编辑器剪切/变速/字幕/GIF 等（细节见归档总结）。

**非目标**：注册/登录/账号、Sparkle、上传（Google Drive/imgbb/S3）、在线翻译、PII 自动打码、可编辑光标/按键 HUD/摄像头画中画、视频缩放/定格/视频打码轨道、自定义图片印章。

## Capabilities

### New Capabilities

- `capture-overlay-parity`：区域截图覆盖层的工具条结构、布局几何、Retina 像素语义、冻结帧抓取与权限/热键行为。

### Modified Capabilities

- 无既有 spec 直接修改；`capture` 模块此前没有独立 spec，本变更将其覆盖层行为固化为 `capture-overlay-parity`。

## Impact

- 代码：`Sources/MacShotKit/CaptureToolbar.swift`（新增）、`AreaSelectionController.swift`、`ScreenCaptureService.swift`、`MacShotController.swift`、`PinWindowController.swift`、`GlobalHotKeys.swift`、`Build/build.sh`。
- 权限：不新增系统权限；屏幕录制授权仍按签名生效。
- 兼容性：保存文件名默认模板与 macshot 一致（`Screenshot yyyy-MM-dd at HH-mm-ss`）；旧历史记录/编辑会话不受影响。
- 风险：冻结帧改为异步，极快按下 Enter 时可能回退到同步抓图；多屏不同缩放比例时统一使用最大 scale。
