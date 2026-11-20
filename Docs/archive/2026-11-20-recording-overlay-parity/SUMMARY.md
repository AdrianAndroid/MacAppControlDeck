# 2026-11-20 · 录屏/GIF 覆盖层与编辑流程对齐总结

## 问题

- 点击「录制屏幕（区域）」/「录制 GIF（区域）」复用了截图覆盖层：显示标注工具，没有录制设置；
- 停止后没有视频编辑界面；
- 录制产出无视频轨的空文件，HUD 停止按钮第一次点击无效。

## 改动

### 录制覆盖层（按 macshot 的录制模式）

- 隐藏横向标注工具条与选项行；
- 右侧动作栏：开始录制（红色）、取消、系统声音、麦克风、格式/帧率设置；
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
4. HUD 是非激活面板，按钮吞掉第一次点击：`HUDButton` 覆盖 `acceptsFirstMouse`。
5. 2.5 秒无屏幕帧自动停止并提示重新授权；零视频帧视为失败，不打开编辑器。
6. 菜单新增根级「停止录屏」，录制中可直接点击。

## 验证

- 录制覆盖层截图：仅右侧录制动作栏，无标注工具。
- 区域录制 177 秒：1182×720、30fps、视频轨 + 音频轨；停止后自动打开「录屏编辑」窗口。
- HUD 停止按钮首次点击即完成停止与文件写入。

## 对照说明

布局与动作集合取自上游 `ToolbarDefinitions.rightButtons(isRecording:)`：开始/取消/鼠标高亮/按键/系统声音/麦克风/摄像头/设置/移动选区。本仓库暂未移植鼠标高亮、按键显示与摄像头画中画，其余动作已对齐。

## 相关文件

- `Sources/MacShotKit/AreaSelectionController.swift`、`CaptureToolbar.swift`
- `Sources/MacShotKit/MacShotController.swift`、`ScreenRecorder.swift`、`RecordingHUD.swift`
- `Sources/MacShotKit/VideoEditorController.swift`
- `Sources/MacAppControlDeck/Modules/Capture/CaptureModule.swift`
- OpenSpec：`openspec/changes/archive/2026-11-20-recording-overlay-parity/`、`openspec/specs/recording-overlay-parity/spec.md`
