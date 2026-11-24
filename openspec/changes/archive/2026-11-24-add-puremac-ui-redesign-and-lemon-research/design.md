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

> 归档校正（2026-11-24）：决策 1/2 为最初设想（左轨 shell），**实际未采用**；实施阶段复核柠檬后
> 改为决策 1′/2′（顶部页签 v3）。两套都保留以便追溯，以 1′/2′ 及第 7 节为归档事实。

1. （最初设想，未采用）导航从顶部 tab 改为左轨：与上游 PureMac、macOS 系统设置一致；640pt 收成 56pt 图标栏。
2. （最初设想，未采用）一 shell + 六个内容区：新增 `Sidebar`/`PageHeader`/`FilterStrip`/`SummaryBar`/`Badge`/`Chip`，删掉各页重复标题、统计与脚注。
1′. **（实际采用）保留现有顶部 6 页签导航**：复核柠檬后按「基于现有基础、最小改动」收敛，不动导航骨架，只把「入口 → 扫描 → 结果 → 确认」四层交互对齐柠檬（设计文档第 10 节 v3）。理由：不碰清理引擎与安全边界，改动面最小。
2′. **（实际采用）统一组件而非重写 shell**：在 `SystemToolComponents.swift` 新增 `EmptyScanState`/`ScanningStateView`/`StatusCapsule`/`CollapsibleGroupHeader`，逐页替换空态、扫描态、分组头与状态列，不新增 `SystemToolShell.swift`。
3. **操作就近**：扫描/取消跟随页内；选中统计与清理在表格上方；底部 StatusBar 只报全局状态、进度与失败数；取消走二次确认（进度丢失文案）。
4. **三态只换内容区**：`SystemToolPhase` 驱动主按钮与状态栏，不改变页签布局；扫描态显示当前路径 + 不定长进度条，**不显示百分比**（柠檬实测无百分比）。
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

- 顶部页签在最小宽度下较拥挤；v3 未改导航骨架，未做 640pt 图标栏折叠（v2 设想未实施）。
- 表格列宽目前固定，长路径仍靠 middle truncation；不引入可拖拽列宽。
- 截图验收依赖本机屏幕录制权限，必须在固定签名包上执行。
- 柠檬逐页调研（隐私清理/开机启动/磁盘分析等）未在本变更采集，详见 tasks 第 3 节原因。

## 7. 实际实施记录（归档补充）

按 v3（顶部页签 + 四层交互对齐柠檬）落地，另修复三处实际发现的缺陷：

| 项 | 文件 | 处理 |
| --- | --- | --- |
| 统一组件与三态 | `SystemToolComponents.swift`、`SystemToolViews.swift`、`SystemToolViews2.swift` | 入口卡、路径进度扫描态、状态胶囊、分组折叠、分类 tab、概览引导区 |
| 取消二次确认 | `SystemToolState.swift`、`SystemToolViews.swift` | `requestCancelScan` + `cancelConfirmationPending`，文案含「进度丢失，下次需重新开始」 |
| 菜单入口消失 | `UI/MenuBarController.swift` | 删除 main 遗留调试代码 `button?.title = "A\(menu.items.count)"`，恢复滑块图标；用户偏好 `module.enabled.systemTool` 由 0 改回 1 |
| 状态栏数字被裁 | `Modules/SystemTool/SystemToolModule.swift` | 自定义 `StatusMetricView`（NSView 自绘两行，`draw(at:)` 左下角坐标）替代多行 `attributedTitle`，数值行完整居中 |

验收：`swift build --disable-sandbox` 通过；`SystemToolTests` 10/10 全绿；release + Sparkle 嵌入 + 固定签名 DR 校验通过；覆盖安装截图确认状态项数字完整、菜单入口恢复正常。

关于 rebase：开发前已将本分支 rebase 到最新 main（`1a7d988`），解决 README / BuiltinActions / PanelHTML / remote-web-panel spec 四处叠加冲突并保留双方内容；`BuiltinActions.swift` 冲突解决时漏掉的逗号已修复。
