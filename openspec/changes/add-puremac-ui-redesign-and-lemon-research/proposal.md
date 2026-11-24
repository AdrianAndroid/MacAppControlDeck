# 提案：记录 PureMac 新 UI 设计与腾讯柠檬调研方案

## Why

PureMac 模块的第一版 UI 是"功能优先"堆出来的：6 个页签各自实现标题、说明、操作、统计和脚注，间距与字号不统一，扫描/取消/清理分散在页内和底部两处，视线来回跳。用户已确认现有界面不达标，需要在回家后按一套统一的信息架构重做。

同时，本模块的直接竞品是腾讯柠檬清理。用户希望在**不打断当前工作**的前提下调研它的全部功能页面并留存截图，作为 PureMac 的交互与功能对照；公司环境不适合继续操作桌面 App，因此需要把已完成的调研证据和可复现的操作方案先落盘。

本变更只沉淀文档与截图资产，不实施 UI 代码，不改清理逻辑。

## What Changes

- 新增 `Docs/plans/2026-11-24-puremac-ui-redesign.md`：完整 UI 重设计方案，含 14 组 ASCII 图（整窗骨架、统一页面骨架、6 个页签、三态、响应式、组件规格、4 个确认弹窗、设置页、侧栏折叠态）、Token 表与落地映射。
- 新增 `Docs/research/2026-11-24-tencent-lemon.md`：腾讯柠檬 5.3.9 调研方案，含功能地图、已收集证据、后台/前台两种操作路径、精确命令与坐标、已知限制、回家继续的 checklist、与 PureMac 的初步对比。
- 新增 `Docs/research/tencent-lemon/screenshots/`：6 张真机截图（首页、大文件入口、大文件结果、重复文件入口、相似照片入口、应用卸载列表）。
- 新增 `Docs/research/tencent-lemon/tools/`：`shot.sh`（截图并读取 AX 树）与 `clickto.swift`（后台坐标点击尝试）。
- 新增 OpenSpec 变更跟踪 UI 重设计与调研补全；`system-cleaner` 增加统一信息架构要求，`project-documentation` 增加调研文档可复现要求。

**非目标**：

- 本次不写任何 UI 代码，不新增/修改 `Sources/` 下的 Swift 文件。
- 不完成柠檬全部功能页截图（隐私清理、开机启动项、磁盘空间分析、柠檬精选、相似照片结果、重复文件结果、卸载详情、设置页仍未采集）。
- 不修改清理引擎、安全边界、签名、Bundle ID 或权限。

## Capabilities

### New Capabilities

- `project-documentation`：调研类文档必须可复现、证据可追溯。

### Modified Capabilities

- `system-cleaner`：新增 PureMac 窗口统一信息架构与三态要求。

## Impact

- 文档：新增 2 份 Markdown、6 张 PNG、2 个脚本；不改 README 功能描述。
- 代码：无。
- 依赖：无。
- 权限与签名：无变化。
- 用户可见入口：无（纯文档与资产，按 R0 写明"无用户可见入口"）。
- 风险：截图来自本机真实文件列表（应用名、大文件名），提交前已确认不含账号、密钥或隐私内容；如需入库可后续脱敏。
