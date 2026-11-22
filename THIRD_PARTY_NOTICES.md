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

## UI 草图内置素材库（`Web/sketch/libraries`）

以下 16 组素材库来自 Excalidraw 官方素材库仓库
https://github.com/excalidraw/excalidraw-libraries ，均标注 **MIT License**。
原始文件以 `.excalidrawlib` 形式保存在 `Web/sketch/libraries/`，构建时由
`Web/sketch/scripts/prepare-libraries.mjs` 统一转换为 Excalidraw 0.18 的
`libraryItems` 结构，并打包进 `Resources/Sketch` 离线使用。

| 素材库 | 作者 / 来源 | 组件数 |
|---|---|---:|
| Basic UX/wireframing elements | gabrielamacakova | 69 |
| Lo-Fi Wireframing Kit | spfr | 23 |
| Web Kit | excacomp | 9 |
| Mobile Kit | excacomp | 3 |
| Forms | g-script | 26 |
| HTML input elements | marwinburesch | 8 |
| Universal UI kit | manuelernestog | 22 |
| Dropdowns | h7y | 3 |
| Apple Devices Frames | franky47 | 13 |
| Awesome Icons | ferminrp | 24 |
| Basic shapes | pgilfernandez | 32 |
| Sticky Notes | ferminrp | 13 |
| Bubbles | ocapraro | 4 |
| Gadgets | morgemoensch | 5 |
| Software Architecture | youritjang | 7 |
| System Design Components | rohanp | 24 |

- 素材仅保存在本地，不请求 libraries.excalidraw.com 或 Excalidraw 云服务。
- MIT License 允许商用、修改与再分发，但分发时须保留原作者的版权与许可声明；
  完整仓库级许可见上游 `LICENSE`。
- 页面「精选素材」面板底部保留来源与许可标识；用户从面板或原生「素材库」按钮
  均可访问这些素材。

## 万年历历法数据（`6tail/lunar-swift`）

- 上游：https://github.com/6tail/lunar-swift
- 许可证：MIT License
- 引入方式：Swift Package Manager 依赖，产品名 `LunarSwift`，固定版本 `1.1.9`。
- 使用范围：仅使用农历、干支、生肖、节气、节日、宜忌与法定节假日数据；
  不引入上游 UI、示例应用或其他平台代码。
- 生效模块：`Sources/MacAppControlDeck/Modules/Calendar/`。
- 不联网：所有计算在本地完成，不请求上游或第三方服务。
- 法定节假日数据由上游按年维护；升级依赖后需回归 2027 年及以后节假日。

## 桌宠 BongoCat standard 模型与键位素材

- 上游：https://github.com/ayangweb/BongoCat
- 固定版本：`47a73ed1765b13fdd674ec356d51b5b16a6b5a5b`
- 许可证：Apache License 2.0，许可证原文随包放在
  `MacAppControlDeck.app/Contents/Resources/Licenses/BongoCat-LICENSE.txt`。
- 引入目录：`Sources/MacAppControlDeck/Modules/Pet/Resources/live2d/bongocat-standard/`，
  包含 standard Live2D 模型、键位高亮图与官方背景原图。
- 修改说明：本项目新增 `resources/background.clean.png`（由用户提供的概念图生成，
  去掉白桌、猫和猫爪，保留完整圆角鼠标垫与键盘），并在 `app.js` 中改用它；
  官方 `background.png`、模型和键位图保持原样。
- 使用时保留上游版权与许可声明；不暗示上游对本项目的背书。
