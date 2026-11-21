# README 功能截图与使用路径（2026-11-21）

## 需求背景

README 当时只有文字说明，功能与使用方式需要读者自己在大段描述里找。用户要求把“所有功能截图、使用方式截图”放进 README，并推送到 GitHub 的 `AdrianAndroid/MacAppControlDeck`。

## 需求目标

1. 用**真实运行界面**替换纯文字说明，覆盖菜单栏、设置、截图/录屏、UI 草图、手机端。
2. 截图按使用路径嵌入对应章节，而不是全部堆在文末。
3. 控制仓库体积，统一裁剪与压缩，去掉无关桌面窗口和隐私内容。
4. 完成后提交并推送 `main`。

## 最终方案

- 新增 `Docs/images/readme/`，存放 **14 张 PNG，合计约 1.4 MB**。
- README 顶部增加「菜单栏 + 手机面板」双栏总览。
- 「Mac 端使用」插入主菜单与电脑控制子菜单。
- 新增「截图、录屏与视频剪辑」章节：子菜单、设置页、区域截图选区 + 5 步使用路径。
- 新增「UI 草图」章节：画板、精选素材库 + 5 步使用路径。
- 「手机端使用」插入首次配对页与已配对面板。
- 新增「设置界面」章节：通用、菜单、模块、UI 草图、设备页。
- 顺手修正 README 测试数量：`40 项` → `51 项`。

## 截图清单

| 文件 | 内容 | 使用位置 |
|---|---|---|
| `menu.png` | 菜单栏一级下拉菜单 | 顶部总览、Mac 端使用 |
| `phone-panel.png` | 已配对手机面板（真实按钮数据） | 顶部总览、手机端使用 |
| `phone-pairing.png` | 手机端 6 位配对码页 | 手机端使用 |
| `menu-computer-control.png` | 电脑控制子菜单 | Mac 端使用 |
| `menu-capture-record.png` | 截图与录屏子菜单（截图/OCR/录屏/GIF/历史） | 截图、录屏与视频剪辑 |
| `settings-capture.png` | 截图与录屏设置页 | 截图、录屏与视频剪辑 |
| `capture-selection.png` | 区域截图选区覆盖层 | 截图、录屏与视频剪辑 |
| `sketch-board.png` | UI 草图多画布画板 | UI 草图 |
| `sketch-libraries.png` | 内置精选素材库面板（16 组 / 285 组件） | UI 草图 |
| `settings-general.png` | 通用设置：面板地址、权限、配对、启动 | 设置界面 |
| `settings-menu.png` | 菜单命令显隐、置顶与排序 | 设置界面 |
| `settings-modules.png` | 模块独立开关 | 设置界面 |
| `settings-sketch.png` | UI 草图设置：目录、导出、窗口 | 设置界面 |
| `settings-devices.png` | 已配对设备与撤销配对 | 设置界面 |

图片目录：`Docs/images/readme/`。

## 实施方法

### Mac 界面截图

- 用 `screencapture -x -l <windowID>` 只抓设置窗口，避免桌面其他窗口进入截图。
- 设置页切换遇到的坑：SwiftUI 侧栏在选中项后会滚动，固定屏幕坐标会点到别的页；最终以窗口截图 + 菜单行高亮位置校准，点击后再截窗口。
- 菜单截图来自真实菜单弹出，随后只裁菜单面板，重新合成到浅灰背景，去掉 Finder/浏览器背景与通知横幅。
- 区域截图选区通过手机面板的真实 `builtin.capture.area` 按钮触发，再截取屏幕并裁到选区附近，保留真实遮罩与蓝色选框，不带入无关桌面内容。

### 手机面板截图

- 用无头 Chromium 按 iPhone 视口（390×844，2×）打开面板。
- 已配对面板通过本机 `devices.json` 中已有设备的 token 注入 `localStorage`，再调用真实 `/api/buttons` 渲染，不使用假数据。
- 配对页不注入 token，直接截取真实 6 位配对码界面。
- token 只用于本地截图，未写入仓库、未输出到对话。

### 图片处理

- 设置窗口统一裁成 840×720，最大宽度压到 1000 px。
- 手机截图压到 700 px 宽；画板/素材库最大 1200 px。
- 全部 PNG `optimize=True`；README 用 HTML `width` 控制展示尺寸，避免手机长图撑高页面。

## 验证结果

- README 中 14 个 `<img src>` 路径全部存在，无死链。
- GitHub raw 图片抽查返回 `200`。
- 本地 `main` 与 `origin/main` 指向同一提交，工作区干净。
- 本次只改 README 与图片资产，未重跑 `swift test`；README 中的 51 项与最近一次测试结果一致。

## 提交与产物

- 提交：`67da9f3 docs(readme): add feature screenshots and usage walkthroughs`
- 推送：`origin/main`
- 主要产物：
  - `README.md`
  - `Docs/images/readme/`（14 张截图）
- GitHub：<https://github.com/AdrianAndroid/MacAppControlDeck/blob/main/README.md>

## OpenSpec 归档

- 变更：`openspec/changes/archive/2026-11-21-add-readme-feature-screenshots/`
  - `proposal.md`：需求背景、变更范围、非目标与影响
  - `design.md`：实机截图流程、图片处理、README 排版与取舍
  - `tasks.md`：截图、改写、验证、提交的完整任务清单
  - `specs/project-documentation/spec.md`：本次新增能力的规格增量
- 能力规格：`openspec/specs/project-documentation/spec.md`
- 归档方式：按已有 `openspec/changes/archive/YYYY-MM-DD-<change-id>/` 结构保存，`spec delta` 使用 `## ADDED Requirements`，能力规格使用 `## Purpose` / `## Requirements`。

## 已知限制 / 后续

- 设置页覆盖通用、菜单、模块、设备、截图、UI 草图；**按钮管理页、关于页未单独截图**。
- **标注编辑器、录制 HUD、视频剪辑窗口**属于运行态临时界面，本次用“选区截图 + 设置页 + 使用步骤”表达，未单独截图。
- 若后续要求“每个运行态窗口都有一张图”，建议单独做一轮截图验收，并在截图前清理桌面窗口，避免隐私内容。
- 手机面板为无头浏览器按 iPhone 视口渲染，不是实体 iPhone 截图；数据与接口均为真实。

## 用户可见入口

无。本次只新增文档与截图资产，不改功能代码，因此不涉及内置快捷打开按钮。
