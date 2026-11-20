# 技术设计：截图覆盖层对齐 macshot

## 1. 工具条结构与取值

直接搬运上游三个文件的最小可用版本（去掉录音电平、上传、翻译、主题切换）：

| 上游 | 本仓库 | 说明 |
|---|---|---|
| `UI/Toolbar/ToolbarButtonView.swift` | `CaptureToolbarButtonView` | 32pt 方块，悬停 12% 白，选中紫色，色板按钮画色块，SF Symbol 统一 tint |
| `UI/Toolbar/ToolbarStripView.swift` | `CaptureToolbarStripView` | 4pt 内边距、2pt 间距、6pt 圆角、深色底；横向/纵向两种朝向 |
| `UI/Toolbar/ToolbarDefinitions.swift#ToolbarLayout` | `ToolbarLayout` | 紫色强调色 `0.55/0.30/0.85`、图标白色、底色 `white 0.12` |

按钮集合：

- 横向工具条：移动、矩形、椭圆、直线、箭头、画笔、荧光笔、文字、马赛克、5 个色板 + 调色盘、撤销、重做。
- 选项行：线宽 2/4/8、线型 实/虚/点。
- 竖向动作栏：保存、复制、钉图、OCR、关闭。

## 2. 布局几何（移植 `repositionToolbars()`）

坐标系为覆盖层 view 坐标（原点左下，y 向上）：

1. 竖向动作栏：
   - `rx = selection.maxX + 6`（右侧有 ≥50pt 空间）；
   - 否则 `rx = selection.minX - width - 6`；
   - `ry = selection.maxY - height`（与选区顶对齐）；
   - 选区过窄且两侧都放不下时，放到选区下方右侧。
2. 横向工具条：
   - `belowY = selection.minY - height - 6`，`belowFits = belowY - 38 >= bounds.minY + 4`；
   - `aboveY = selection.maxY + 38 + 6`；
   - 优先下方，放不下则上方；水平居中并夹在边界内。
3. 与竖向栏水平冲突时，按上游顺序尝试：右推、左推、下推。
4. 选项行：`y = bottomBar.minY - rowHeight - 2`（工具条下方），与工具条中心对齐。

拖动/缩放选区时只更新三个 strip 的 frame，不重建按钮。

## 3. Retina 与像素语义

- `ScreenCaptureService.captureAllScreensStitched()` 按屏幕最大 `backingScaleFactor` 创建画布，各屏 frame 同步乘 scale。
- `SelectionView.pixelScale = snapshot.width / bounds.width`：
  - W×H 输入框显示/提交像素值；
  - 预设分辨率（如 1920×1080）按像素换算成 view 尺寸。
- 导出使用显式像素 `NSBitmapImageRep`（`pixelsWide/pixelsHigh`），并用 `NSGraphicsContext(bitmapImageRep:)` 绘制，避免 `NSImage.lockFocus` 在 2x 屏上把输出放大一倍。

## 4. 冻结帧与性能

- `begin()` 先创建并显示遮罩，随后在后台队列抓取多屏画面并拼接，主线程只负责把图像赋给 view。
- 抓帧期间 `SelectionWindow.sharingType = .none`，防止把遮罩/工具条截进背景；完成后恢复 `.readOnly`。
- 吸附像素检测缓存 `NSBitmapImageRep`，鼠标移动时不再重建位图。
- 极快确认时若快照尚未就绪：`commit` 返回 nil 图像，`MacShotController` 回退到同步 `capture(area:on:)`。

## 5. 权限与热键

- 删除「抓其他应用窗口」的探针：该调用在未授权时会被 TCC 阻塞，导致主线程卡死（表现为热键失效、Esc 无效）。
- `ensurePermission()` 不再依赖 `CGPreflightScreenCaptureAccess()`：重签名后它会误报 false。改为直接尝试抓图，只有返回 nil 才弹出授权说明。
- `GlobalHotKeys` 记录 `RegisterEventHotKey` 失败项，每 2 秒重试，避免被 macshot 等程序先占用后永久失效。
- `Build/build.sh` 优先选择任何有效的 `MacAppControlDeck*` 自签名身份（`Dev` 或 `Self-Signed`），保证重建后签名稳定，TCC 授权不失效。

## 6. 钉图 Esc

- `PinHostingView.mouseDown` → `window.makeKey()` + `makeFirstResponder(self)`。
- 存在钉图时安装全局 + 本地 keyDown 监听：
  - 全局：仅当鼠标位于某张钉图内时关闭该图，避免影响其他应用的 Esc；
  - 本地（应用为前台）：关闭鼠标下的、key 的，或最近一张钉图。
- 关闭最后一张钉图后移除监听。

## 7. 取舍

- 未移植上游 `ToolOptionsRowView` 的完整控件（字体、箭头样式、打码模式等），选项行仅保留线宽/线型，保持结构一致但控件精简。
- 未移植 `OverlayView` 的窗口吸附高亮/网格等全部视觉细节，仅保留窗口边线吸附与悬停高亮。
