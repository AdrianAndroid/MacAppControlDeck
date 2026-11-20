# 技术设计：录制覆盖层与录制链路

## 1. 录制模式覆盖层

`AreaSelectionController.beginRecording(initialFormat:completion:)` 复用选区窗口，但：

- `SelectionView.isRecordingSetup = true`；
- 横向工具条与选项行 `isHidden = true`，不创建标注按钮；
- 纵向动作栏（与截图动作栏同一组件）：

| 顺序 | 图标 | 行为 |
|---|---|---|
| 1 | `record.circle`（红色） | 开始录制 |
| 2 | `xmark` | 取消并关闭覆盖层 |
| 3 | `speaker.wave.2.fill / speaker.slash` | 切换系统声音（选中态紫色） |
| 4 | `mic.fill / mic.slash` | 切换麦克风 |
| 5 | `gearshape` | 菜单：格式 MP4/GIF、帧率 15/30/60/120 |

- 录制态不允许画标注；选区仍可拖动/缩放。
- Return 开始录制，Esc 取消。
- 确认后 `commitRecording` 把屏幕、选区、格式、帧率、音频开关交给 `MacShotController`。

## 2. 录制链路

- 入口（区域）总是打开录制覆盖层；GIF 入口传 `initialFormat = .gif`。
- `beginRecording` 固定输出 `.mp4` take（GIF 也在编辑器里导出），文件名使用录屏模板。
- 结束后 `VideoEditorController.present(url, preferGIF:)`，GIF 模式下「导出 GIF」为主按钮。
- 全屏/窗口录制仍直接使用当前设置，结束后同样进入编辑器。

## 3. 录制器修复

问题与原因：

1. **没有任何视频帧**：`start()` 在 `startWriting` 后把 `startedAt = .zero`，而屏幕样本回调只在 `startedAt == nil` 时启动帧定时器，导致定时器永不启动。
   - 修复：`startedAt` 只在首个屏幕帧到达时置零并启动 `DispatchSourceTimer`。
2. **写入器 input 永不应答**：`startSession` 必须在 append 前调用；现在在 `startWriting` 成功后立即调用一次，并用 `sessionStarted` 防止重复。
3. **SCK 缓冲直接 append 报 -16364**：`emitFrame` 将 `CIImage` 重绘到标准 BGRA 缓冲后写入。
4. **停止按钮点一次没反应**：HUD 为 `nonactivatingPanel`，默认 `NSButton` 吞掉首次点击；改为 `HUDButton`，`acceptsFirstMouse = true`。
5. **无画面时静默失败**：2.5 秒未收到屏幕帧时自动停止；导出时视频帧数为 0 视为失败并提示重新授权。
6. **GIF 时长/轨道缺失**：统一使用 MP4 容器，GIF 由编辑器导出。

## 4. 验证

- 录制覆盖层截图：仅右侧录制动作栏，无标注工具。
- 区域录制 177 秒：1182×720、30fps、含视频与音频轨；停止后自动打开「录屏编辑」。
- HUD 停止按钮第一次点击即生效。
