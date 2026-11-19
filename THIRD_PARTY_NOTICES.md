# 第三方代码来源与许可说明

本项目整体按 **GPL-3.0** 分发，见根目录 `LICENSE`。

## macshot

- 上游：https://github.com/sw33tLie/macshot
- 许可证：GPL-3.0
- 引入方式：只移植功能代码，不引入其独立 App 外壳（菜单栏 App、Sparkle 更新、URL Scheme、XPC OCR 服务、独立设置 App 等）。
- 已引入文件：
  - `Sources/MacShotKit/ScreenCaptureManager.swift`（截图引擎，首期用于验证同进程集成）
- 后续计划引入：截图 Overlay、标注编辑器、录屏、历史等（均放在 `Sources/MacShotKit/`，仅允许 `capture` 模块 import）。

## 说明

- `remote`（电脑遥控）模块不包含 macshot 代码，也不依赖 `MacShotKit`。
- `capture`（截图与录屏）模块与 macshot 上游代码是同一功能域，但对外表现为本项目的一个模块，不是独立的 macshot App。
- 若后续分发二进制包，需同时提供本项目的完整对应源码（GPL-3.0 要求）。
