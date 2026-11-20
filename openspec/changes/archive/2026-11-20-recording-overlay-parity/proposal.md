# 提案：录屏/GIF 使用 macshot 的录制覆盖层与编辑流程

## Why

区域录制与 GIF 录制复用了截图覆盖层：显示的是标注工具，没有开始录制、系统声音、麦克风、格式/帧率等录制设置；录制结束后也不会进入视频编辑界面。用户无法确认自己在录屏还是截图，录完也无法编辑。

上游 macshot 的录制分两步：先进入「录制设置」覆盖层（无标注工具），确认后开始录制；结束后统一打开视频编辑器（GIF 以 GIF 导出为主操作）。

## What Changes

- 覆盖层新增录制模式：隐藏横向标注工具条与选项行，仅显示竖向动作栏：开始录制（红色）、取消、系统声音、麦克风、录制设置（格式 MP4/GIF、帧率 15/30/60/120）。
- 录制入口（⌘⇧R / 菜单「录制屏幕（区域）」「录制 GIF（区域）」）改为先打开录制覆盖层；GIF 入口默认格式为 GIF。
- 录制始终产出 MP4 take；GIF 录制结束后打开视频编辑器并默认「导出 GIF」。
- 录制停止后统一打开「录屏编辑」窗口（此前 MP4 才打开）。
- 修复录制无画面/无法停止：
  - 帧定时器必须等首个屏幕帧到达才启动（此前 `startedAt` 提前置零导致永不启动）；
  - `AVAssetWriter` 先 `startSession` 再写帧；
  - HUD 按钮接受首次点击（非激活面板默认吞掉第一次点击）；
  - 2.5 秒无屏幕帧则停止并提示重新授权；零视频帧视为失败，不打开编辑器。

## Impact

- 代码：`AreaSelectionController.swift`（录制模式/录制动作栏/commitRecording）、`CaptureToolbar.swift`（按钮 tint、录制动作）、`MacShotController.swift`（录制入口与 GIF 意图）、`ScreenRecorder.swift`（帧定时器/看门狗/失败判定）、`RecordingHUD.swift`（首次点击）、`VideoEditorController.swift`（preferGIF）、`CaptureModule.swift`（录制菜单）。
- 兼容性：录制文件仍为 MP4（GIF 经编辑器导出）；旧录屏文件可继续编辑。
