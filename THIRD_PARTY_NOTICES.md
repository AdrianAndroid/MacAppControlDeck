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

## UI 草图 Web 包装层（`Web/sketch` + `Resources/Sketch`）

- **Excalidraw** `0.18.1` — MIT License — https://github.com/excalidraw/excalidraw
  - 以 npm 依赖方式引入，构建为离线静态资源，打包在 `MacAppControlDeck_MacAppControlDeck.bundle/Sketch/`。
  - 自定义 `deck-sketch://` scheme 加载，不访问 Excalidraw 云服务、CDN 或协作后端。
- **React** `18.3.1` / **React DOM** `18.3.1` — MIT License — https://react.dev/
- **Vite** `8.3.8` / **@vitejs/plugin-react** `6.3.0` — MIT License — https://vitejs.dev/
- **@excalidraw/mermaid-to-excalidraw** — 仅作为构建期依赖；本项目通过 `src/mermaid-stub.js` 禁用 Mermaid，最终包不包含 Mermaid / KaTeX 运行代码。

### 随 Excalidraw 分发的字体

`Resources/Sketch/fonts` 共 25 个字体文件 / 约 429 KB，来自 Excalidraw npm 包：

| 字体 | 文件数 | 许可证 |
|---|---|---|
| Assistant | 4 | SIL Open Font License 1.1 |
| Excalifont | 7 | SIL Open Font License 1.1 |
| Virgil | 1 | SIL Open Font License 1.1 |
| Cascadia Code | 1 | SIL Open Font License 1.1 |
| Comic Shanns | 4 | SIL Open Font License 1.1 |
| Nunito | 5 | SIL Open Font License 1.1 |
| Lilita One | 2 | SIL Open Font License 1.1 |
| Liberation Sans | 1 | SIL Open Font License 1.1 |

- 未打包 `Xiaolai`（小赖中文手写体），中文回退系统「苹方」。
- 字体完整许可证以各 npm 包内 `LICENSE` / `OFL.txt` 为准。
