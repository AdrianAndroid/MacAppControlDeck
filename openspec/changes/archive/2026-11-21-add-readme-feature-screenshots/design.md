# 技术设计：README 实机截图与使用路径

## 1. 截图来源与真实性

截图全部来自当前构建的真实运行状态，不使用设计稿或手绘示意：

- Mac 端：`/Applications/MacAppControlDeck.app` 真实运行，菜单栏与设置窗口均实机操作。
- 手机端：无头 Chromium 按 iPhone 390×844（2×）视口打开真实面板；已配对面板注入本机 `devices.json` 中已有设备的 token，并调用真实 `/api/buttons` 渲染，不使用假数据。
- UI 草图：使用已提交的真机画板与素材库验收截图，画板内为实际绘制的矩形。

约束：

- token 仅用于本地截图，不写入仓库、不输出到对话。
- 截图裁掉无关桌面窗口、通知横幅与聊天/终端内容；无法裁掉的运行态界面不纳入 README。

## 2. 截图目录与命名

统一放在 `Docs/images/readme/`，作为 README 的稳定资产目录；归档记录只引用，不复制第二份，避免双份维护。

命名使用英文短横线，按“界面位置/功能”命名：

| 文件 | 用途 |
|---|---|
| `menu.png` | 菜单栏一级菜单 |
| `phone-panel.png` | 已配对手机面板 |
| `phone-pairing.png` | 手机配对页 |
| `menu-computer-control.png` | 电脑控制子菜单 |
| `menu-capture-record.png` | 截图与录屏子菜单 |
| `settings-capture.png` | 截图与录屏设置页 |
| `capture-selection.png` | 区域截图选区覆盖层 |
| `sketch-board.png` | UI 草图板 |
| `sketch-libraries.png` | 精选素材库 |
| `settings-general.png` | 通用设置 |
| `settings-menu.png` | 菜单设置 |
| `settings-modules.png` | 模块开关 |
| `settings-sketch.png` | UI 草图设置 |
| `settings-devices.png` | 设备配对 |

## 3. Mac 窗口截图流程

1. 激活 App：`open -a /Applications/MacAppControlDeck.app`。
2. 打开设置：`osascript` 发送 `⌘,`；通过 `CGWindowListCopyWindowInfo` 取设置窗口 id 与 bounds。
3. 抓单窗口：`screencapture -x -l <windowID>`，输出 952×832（含阴影），再裁成 840×720。
4. 切换设置页：
   - SwiftUI 侧栏会随选中项滚动，固定屏幕坐标不可靠；
   - 以窗口截图里的蓝色选中行校准，真实鼠标点击后再抓窗口；
   - 选中视觉与右侧内容可能短暂不同步，必要时再点一次同一行；
   - 最终采用通用、菜单、模块、截图、UI 草图、设备六页。

菜单截图：

- 真实弹出菜单后全屏截图，再只裁菜单面板；
- 重新合成到浅灰渐变背景并加阴影，去掉 Finder/浏览器背景和通知；
- 右上角菜单栏、Dock 等不进入最终图。

区域截图选区：

- 通过手机面板真实的 `builtin.capture.area` 按钮触发；
- 桌面变暗后拖选设置窗口区域，截屏并裁到选区附近；
- 只保留蓝色选框与遮罩，避免带入无关桌面内容。

## 4. 手机面板截图流程

- 启动本机无头 Chromium（`playwright-core`）。
- 配对页：直接打开 `http://127.0.0.1:47615/panel/`，不注入 token，截取 6 位配对码界面。
- 已配对页：读取 `~/Library/Application Support/MacAppControlDeck/devices.json` 的已有设备 token，注入 `localStorage.deck_token`，再打开面板；页面会真实请求 `/api/buttons`。
- 视口 390×844、`deviceScaleFactor=2`、移动 UA；输出 780×1688，README 展示宽度 280–300。

## 5. 图片处理与体积

- 设置窗口裁成 840×720，最大展示宽度 1000 px。
- 手机截图压到 700 px 宽；画板/素材库最大 1200 px。
- PNG `optimize=True`；14 张合计约 1.4 MB。
- README 用 HTML `width` 约束手机长图，避免把页面撑得过高。
- 所有图片使用仓库相对路径 `Docs/images/readme/...`，便于 GitHub 直接渲染。

## 6. README 排版

- 顶部总览：菜单栏 + 手机面板双栏；图下加简短说明。
- 「Mac 端使用」：主菜单与电脑控制子菜单。
- 新增「截图、录屏与视频剪辑」：子菜单 + 设置页 + 选区图，后接 5 步使用路径。
- 新增「UI 草图」：画板 + 素材库，后接 5 步使用路径。
- 「手机端使用」：配对页 + 已配对面板。
- 新增「设置界面」：六页两列/跨列排布，配一句职责说明。
- 「归档」索引加入 Docs 与 OpenSpec 两个入口。

## 7. 取舍与风险

- 设置页只覆盖主要页面：按钮管理页、关于页未单独截图；按钮管理仍由文字步骤说明。
- 标注编辑器、录制 HUD、视频剪辑窗口属于运行态临时界面，本次未捕获；以选区截图与设置页表达。
- 无头浏览器按 iPhone 视口渲染，不是实体 iPhone 截图，但数据与接口真实；README 文案不宣称是实体机截图。
- 截图会随界面变化而过期，后续界面改动必须同步更新对应图片；这是 `project-documentation` 能力中的维护义务。
- 设置页权限状态因机器而异，README 不把某台机器的“未授权/已授权”状态当成产品默认状态。
