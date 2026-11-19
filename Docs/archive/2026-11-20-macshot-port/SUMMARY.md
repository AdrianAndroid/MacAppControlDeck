# 2026-11-20 · macshot 能力移植总结

## 目标

把 <https://github.com/sw33tLie/macshot> README 中可本地实现的能力移植到 `MacAppControlDeck` 的 `capture` 模块；注册、登录、Sparkle 自动更新、账号上传不移植。

## 完成内容

- 截图：全屏、区域、窗口、滚动；延时 0/3/5/10/30 秒；快速保存、快速 OCR；历史记录。
- 标注：矩形、实心矩形、椭圆、直线、箭头、画笔、荧光笔、文字、序号、马赛克、模糊、聚光灯、测量、裁剪；撤销/重做。
- 输出：PNG/JPEG/HEIC/WebP/AVIF，质量滑块；保存目录可配置。
- OCR：Vision 中英文识别，结果可复制；快速 OCR 自动复制。
- 录屏：区域/全屏/窗口 MP4（H.264 + AAC 系统音频）、区域 GIF；帧率可选；HUD、菜单栏停止。
- 其他：钉图、最近截图历史、停止录屏、目录跳转。

## 关键技术问题与修复

### 1. 录屏 HUD 主线程崩溃

现象：开始录制后日志 `NSWindow should only be instantiated on the main thread!`，应用崩溃，MP4 为 0 字节。

修复：`MacShotController.beginRecording` 使用 `Task { @MainActor in ... }`；`RecordingHUDController.show` 增加 `Thread.isMainThread` 兜底。

### 2. MP4 只有约 2 帧 / 35KB

现象：ScreenCaptureKit 画面静止时只给少量 `.complete` 帧；直接 append sample buffer 到 `AVAssetWriterInput` 报 `-16122`。

修复：
- 不再直接把 SCStream 的 sample buffer 交给 H.264 编码器；
- 以 `DispatchSourceTimer` 按目标 fps 把「最近一帧」重绘到 `CVPixelBuffer`，写入 `AVAssetWriterInputPixelBufferAdaptor`；
- 视频 PTS 用帧序号生成，音频 PTS 用首个音频帧归零。

结果：800×550 MP4，150 帧 / 5.00 秒，H.264 + AAC，音画时长一致。

### 3. 截图编辑器坐标/裁剪

- 编辑器用 SwiftUI `Canvas` 预览，最终用 `NSGraphicsContext(flipped: true)` + `NSBezierPath` 渲染。
- 裁剪、标注位置、像素坐标与 Retina 缩放已通过区域截图 + 红色矩形保存验证。

### 4. 滚动截图拼接

- 自动向下滚动选区，抓取多帧后按底部重叠区域匹配。
- 使用 CoreImage 按「最后一帧在最底部、第一帧在最顶部」倒序合成，避免 CGImage 裁剪原点导致的上下颠倒。
- 已知限制：选区包含固定侧栏/工具栏时，固定区域会在长图中重复；建议只框选可滚动内容。

## 验证

- `swift build` 通过；`swift test` 41 项全部通过。
- 区域截图、窗口截图、全屏截图进入编辑器正常。
- 标注矩形保存后位置正确；OCR 可用。
- 快速保存 JPEG 扩展名/格式正确。
- 快速 OCR 识别文字并自动复制。
- 区域 MP4 5 秒 / 150 帧 / 音频 4.8 秒；GIF 53 帧 800×550。
- 滚动截图输出 800×2022 长图，方向正确。

## 未移植

注册/登录、Sparkle、Google Drive/imgbb/S3 上传、翻译、麦克风、点击高亮、视频编辑器、Beautify、图像调整、PII 自动打码、QR/条码、Liquid Glass 等。原因见 `Docs/architecture/MACSHOT_PORT.md`。
