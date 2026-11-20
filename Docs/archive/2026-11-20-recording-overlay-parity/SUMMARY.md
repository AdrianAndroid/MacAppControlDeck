# 2026-11-20 · 录屏/GIF 覆盖层与编辑流程对齐总结

## 问题

- 点击「录制屏幕（区域）」/「录制 GIF（区域）」复用了截图覆盖层：显示标注工具，没有录制设置；
- 停止后没有视频编辑界面；
- 录制产出无视频轨的空文件，HUD 停止按钮第一次点击无效。

## 改动

### 录制覆盖层（按 macshot 的录制模式，实机对照）

- 隐藏横向标注工具条与选项行；
- 右侧动作栏：开始录制（红色）、取消、鼠标点击高亮、系统声音、麦克风、格式/帧率设置；
- **无 3-2-1 倒计时**：macshot 默认 `delay = 0` 时直接进入选区录制（仅 delay>0 才倒计时），本版已删除倒计时；
- Return 开始、Esc 取消；录制态不可标注，但可调整选区；
- GIF 入口默认格式 GIF。

### 录制链路

- 录制始终产出 MP4 take；结束后统一打开「录屏编辑」；
- GIF 录制在编辑器中以「导出 GIF」为主操作（与 macshot 一致）；
- 全屏/窗口录制结束后同样进入编辑器。

### 录制器修复

1. 帧定时器永不启动：`startedAt` 在 `startWriting` 后被提前置零，改为首个屏幕帧到达时启动。
2. `startSession` 必须在 append 前：现在在 `startWriting` 后立即调用一次。
3. SCK 缓冲直接 append 报 -16364：经 CIImage 重绘到标准 BGRA 缓冲后写入。
3.1 音画不同步：视频 PTS 原本按帧序号 / fps 估算，掉帧即越录越偏；改为真实经过时间（`CACurrentMediaTime`）并与音频同一时间基准。实测 71 秒录制：视频 71.27s、音频 71.18s。
4. HUD 是非激活面板，按钮吞掉第一次点击：`HUDButton` 覆盖 `acceptsFirstMouse`。
5. 2.5 秒无屏幕帧自动停止并提示重新授权；零视频帧视为失败，不打开编辑器。
6. 菜单新增根级「停止录屏」，录制中可直接点击。

## 验证

- 录制覆盖层截图：仅右侧录制动作栏，无标注工具。
- 区域录制 71 秒：视频 71.27s / 音频 71.18s（相差 0.09s），30fps，停止后自动打开「录屏编辑」窗口。
- 录制入口确认无倒计时，直接进入选区录制（与 macshot 实机一致）。
- HUD 停止按钮首次点击即完成停止与文件写入。

## 录制核心改为直接搬运上游源码

`Sources/MacShotKit/Upstream/Recording/` 现包含上游原文件（未重写）：

- `RecordingEngine.swift`、`RecordingLifecycle.swift`、`RecordingConfiguration.swift`
- `MP4WriterSession.swift`、`RecordingSessionStore.swift`
- `VideoFrameCadence.swift`、`VideoEncodingSettings.swift`、`RecordingAudioSilence.swift`
- `CursorTelemetry.swift`、`CursorTelemetryRecorder.swift`、`CameraPlacementTrack.swift`、`VideoCameraRecorder.swift`
- `MicrophoneCapture.swift`、`MicrophoneDeviceSelection.swift`、`RecordingClock.swift`、`SafeNumerics.swift`
- `RecordingSampleValidation.swift`、`SampleBufferTiming.swift`、`LenientDecoding.swift`、`Compat.swift`

适配点只有两处：会话目录改为本应用的 Application Support；`L()` 使用最小占位实现。

实测：上游引擎录制 28.7 秒，视频 28.687s / 音频 28.640s（相差 0.047s），生成 `cursor.mstl` 遥测与 `session.plist`，停止后自动打开编辑器。

视频编辑器已整体搬运：`Upstream/VideoEditor/` 40+ 文件（窗口控制器、时间线、检视器、舞台、项目模型、场景渲染、导出管线），录制结束即打开与 macshot 同源的编辑器（左侧轨道 + 舞台 + 多轨时间线 + Copy/Export）。上传/翻译通过 `-DOFFLINE` 关闭。

仍待搬运：`OverlayView` / `OverlayWindowController` / `ToolOptionsRowView`，当前覆盖层仍是自实现。

## 对照说明

布局与动作集合取自上游 `ToolbarDefinitions.rightButtons(isRecording:)`：开始/取消/鼠标高亮/按键/系统声音/麦克风/摄像头/设置/移动选区。本仓库暂未移植鼠标高亮、按键显示与摄像头画中画，其余动作已对齐。

## 相关文件

- `Sources/MacShotKit/AreaSelectionController.swift`、`CaptureToolbar.swift`
- `Sources/MacShotKit/MacShotController.swift`、`ScreenRecorder.swift`、`RecordingHUD.swift`
- `Sources/MacShotKit/VideoEditorController.swift`
- `Sources/MacAppControlDeck/Modules/Capture/CaptureModule.swift`
- OpenSpec：`openspec/changes/archive/2026-11-20-recording-overlay-parity/`、`openspec/specs/recording-overlay-parity/spec.md`
