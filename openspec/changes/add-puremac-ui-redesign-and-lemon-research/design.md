# 设计：PureMac UI 重做与柠檬调研记录

## 1. 现状诊断

| 问题 | 表现 | 代码位置 |
| --- | --- | --- |
| 信息架构不统一 | 6 个页签各自实现标题/说明/操作/统计/脚注，间距 12/10/8/6 混用，字号 headline/caption 混用 | `SystemToolViews.swift`、`SystemToolViews2.swift` |
| 操作入口分裂 | 扫描在页中上部，取消在页内与底部各一份，清理只在底部 | `SystemToolViews.swift:132-201` |
| 导航弱 | 顶部横排 6 个「图标+文字」，640pt 最小宽度下拥挤，无强调条 | `SystemToolViews.swift:103-128` |
| 概览太散 | 6 张 108pt 小卡 3 列，720pt 下每卡约 176pt；无磁盘主卡 | `SystemToolViews.swift:205-305` |
| 空态叠加 | 空态占满整页，同时保留筛选/统计/脚注 | `SystemToolComponents.swift:64-93` |
| 层级不清 | `windowBackground` / `controlBackground` / `textBackground` 三层灰无边界 | `SystemToolComponents.swift:97-119` |

## 2. 参考与取舍

| 参考 | 采用 | 不采用 |
| --- | --- | --- |
| 上游 PureMac（SwiftUI 原生，侧栏导航） | 左侧栏 + 内容区 | 其 Protection / App Updates 等未移植页面 |
| macOS 系统设置、本项目 `SettingsView` 侧栏 | 同样的 `sidebarRow` 视觉与宽度 | — |
| 活动监视器 | 表格双行、CPU/内存列、系统进程置灰、按资源排序 | 其列宽拖拽与多标签（超出本模块范围） |
| CleanMyMac 类清理工具 | PageHeader 主操作、FilterStrip、SummaryBar、危险分级 | 「一键智能清理」大按钮（与「默认零选中」安全契约冲突） |
| Apple HIG | 8pt 网格、字号阶梯、语义色、44pt 行高 | — |

## 3. 关键决策

1. **导航从顶部 tab 改为左轨**：与上游 PureMac、macOS 系统设置、本项目设置页三处一致；640pt 时自动收成 56pt 图标栏。
2. **一 shell + 六个内容区**：新增 `Sidebar` / `PageHeader` / `FilterStrip` / `SummaryBar` / `Badge` / `Chip`，每页只保留自己的内容；删掉各页重复的标题、统计行与脚注。
3. **操作就近**：扫描/取消跟随 PageHeader；选中统计与清理跟随 SummaryBar（表格上方）；底部 StatusBar 只报全局状态、进度与失败数。
4. **三态只换两处**：`SystemToolPhase` 驱动 PageHeader 主按钮与 StatusBar，不改变布局。
5. **安全模型不变**：默认零选中、keeper 徽标、永久删除二次确认、系统路径与符号链接跳过，UI 只做可视化，不放松校验。
6. **设置页与窗口内筛选同源**：都写同一份 `UserDefaults`；设置页负责默认值、排除路径与安全说明，窗口内负责本次扫描的临时覆盖。

## 4. 详细设计

完整 ASCII 图集、Token 表与逐文件落地映射见：

- `Docs/plans/2026-11-24-puremac-ui-redesign.md`

## 5. 实施顺序（回家后）

1. 新增 `SystemToolShell.swift`（Sidebar、PageHeader、FilterStrip、SummaryBar、Badge、Chip）。
2. `SystemToolRootView` 换成左轨布局，接入统一 StatusBar。
3. 概览改 2 列 + 磁盘主卡；垃圾清理、大文件、重复文件、进程、卸载逐页迁入 shell。
4. 调整 `SystemToolComponents` 的行高与字号 token。
5. 真机按 640 / 720 / 900 三档截图验收，再跑 `swift test`。

## 6. 已知限制

- 左轨在 640pt 收成图标后，需要 tooltip 或 hover 提示补全名称。
- 表格列宽目前固定，长路径仍靠 middle truncation；不引入可拖拽列宽。
- 截图验收依赖本机屏幕录制权限，必须在固定签名包上执行。
