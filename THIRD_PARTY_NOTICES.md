# 第三方代码来源与许可说明

本项目整体按 **GPL-3.0** 分发，见根目录 `LICENSE`。

## macshot

- 上游：https://github.com/sw33tLie/macshot
- 许可证：GPL-3.0
- 引入方式：原样 vendor 功能源码，只通过薄适配层接入；不引入其独立 App 外壳（菜单栏 App、Sparkle 更新、URL Scheme、XPC OCR 服务、独立设置 App 等）。
- 已引入目录（均位于 `Sources/MacShotKit/Upstream/`）：
  - `Overlay/`：截图覆盖层、工具栏、标注、钉图/OCR 出口、滚动 HUD 与预览
  - `Recording/`：录屏引擎、MP4 writer、麦克风、指针/按键 telemetry
  - `VideoEditor/`：时间线编辑器、导出、GIF、光标/键盘叠加渲染
  - `Capture/`：滚动截图采集、帧匹配、拼接
  - `Windows/`：倒计时等共享窗口
- 适配层：`Sources/MacShotKit/OverlayCoordinator.swift`、`Sources/MacShotKit/MacShotController.swift`
- 集成方法与验收标准见 `Docs/architecture/UPSTREAM_PORTING.md`。

## 说明

- `remote`（电脑遥控）模块不包含 macshot 代码，也不依赖 `MacShotKit`。
- `capture`（截图与录屏）模块与 macshot 上游代码是同一功能域，但对外表现为本项目的一个模块，不是独立的 macshot App。
- 若后续分发二进制包，需同时提供本项目的完整对应源码（GPL-3.0 要求）。
