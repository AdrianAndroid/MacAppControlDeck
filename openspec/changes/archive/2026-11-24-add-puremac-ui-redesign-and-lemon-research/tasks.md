# 任务：PureMac UI 重做与柠檬调研记录

> 归档说明（2026-11-24）：本变更最初定位为「纯文档 + 左轨 sidebar 方案」，实际实施阶段
> 经复核改为「保留顶部页签的最小改动方案（v3）」，并附带修复了菜单入口与状态栏显示缺陷。
> 下方第 2 节已按**实际落地内容**重写并勾选；未做的第 3 节柠檬逐页调研补全如实标注原因，
> 不冒记完成。

## 1. 文档与证据（已完成）

- [x] 1.1 新增 `Docs/plans/2026-11-24-puremac-ui-redesign.md`：现状诊断、参考取舍、ASCII 图、Token、落地映射
- [x] 1.2 新增 `Docs/research/2026-11-24-tencent-lemon.md`：功能地图、证据、操作路径、命令与坐标、待办 checklist
- [x] 1.3 归档 6 张柠檬真机截图到 `Docs/research/tencent-lemon/screenshots/`
- [x] 1.4 归档截图与点击脚本到 `Docs/research/tencent-lemon/tools/`
- [x] 1.5 建立 OpenSpec 变更，补 `system-cleaner` 与 `project-documentation` 的 delta
- [x] 1.6 二次实操复核柠檬交互，文档补第 11 节复核结论；设计文档补第 9/10 节（v2/v3 定稿）

## 2. UI 实施（实际落地：顶部页签 v3 + 缺陷修复）

> 与最初 design.md 的差异：原方案主张「左轨 sidebar」。复核柠檬后按「基于现有顶部页签、
> 最小改动」原则实施（见设计文档第 10 节 v3）。不新增 `SystemToolShell.swift`，保留现有导航。

- [x] 2.1 `SystemToolComponents.swift` 新增统一组件：`EmptyScanState`（入口卡）、`ScanningStateView`（当前路径 + 不定长进度条，无百分比）、`StatusCapsule`、`CollapsibleGroupHeader`
- [x] 2.2 `SystemToolViews.swift`：概览加引导区（上次扫描 + 可清理总量 + 开始扫描）；状态栏扫描态去百分比改路径进度
- [x] 2.3 取消扫描统一走二次确认（`SystemToolState` 新增 `requestCancelScan` / `cancelConfirmationPending`，文案含「进度丢失，下次需重新开始」）
- [x] 2.4 `SystemToolViews2.swift`：大文件加分类 tab（全部/文档/视频/音频/安装包/其他）+ 按大小分桶折叠
- [x] 2.5 垃圾清理 / 大文件 / 重复文件页的空态与扫描态改用统一入口卡与扫描态组件
- [x] 2.6 `SystemToolViews2.swift`：进程页加状态胶囊列（正常 / 系统进程），系统进程置灰
- [x] 2.7 修复菜单入口：删除 `MenuBarController.install()` 中 main 分支遗留的调试代码（`button?.title = "A\(menu.items.count)"`），恢复滑块图标
- [x] 2.8 修复 PureMac 模块被误关的用户偏好（`module.enabled.systemTool = 0` → 1），恢复二级菜单与状态项点击
- [x] 2.9 修复状态栏 CPU/MEM 数字顶部被裁：`SystemToolModule.swift` 改用自定义 `StatusMetricView`（NSView 自绘两行）替代多行 `attributedTitle`，垂直居中完整显示
- [x] 2.10 编译通过、`SystemToolTests` 10/10 全绿、release 构建 + Sparkle 嵌入 + 固定签名 DR 校验通过、覆盖安装并截图验收

## 3. 柠檬逐页调研补全（未在本变更范围，如实标注）

> 原因：本轮按用户「先调研操作方式 → 总结规律 → 设计 UI → 输出 ASCII 图，先不开发」的收敛指令，
> 只做了入口态与操作方式的二次复核（已记入调研文档第 11 节），未逐页采集下列界面的完整截图与流程。
> 这些项保留为待办，后续如需可由独立调研变更承接。

- [ ] 3.1 隐私清理：入口页 + 扫描结果 — 未采集（非本次 UI 对齐所需）
- [ ] 3.2 开机启动项管理：列表与开关态 — 未采集
- [ ] 3.3 磁盘空间分析：扫描结果与分类视图 — 未采集
- [ ] 3.4 柠檬精选：页面结构 — 确认为外链，未深入
- [ ] 3.5 相似照片：添加文件夹 → 扫描结果 → 分组 — 入口态已记录，结果页未走完（Orca 文件面板键盘输入受限）
- [ ] 3.6 重复文件：添加文件夹 → 扫描结果 → 分组 — 入口态已记录，结果页未走完（同上）
- [ ] 3.7 应用卸载详情：关联文件/残留列表 — 列表已采集，详情未深入
- [ ] 3.8 首页「开始扫描」的智能扫描结果页 — 未采集
- [ ] 3.9 菜单栏状态项与设置页（若存在）— 未采集
- [ ] 3.10 补全调研文档的对比表与结论 — 已给出初步对比（文档第 9 节），逐项结论待上述采集后补全

## 4. 收尾

- [x] 4.1 归档变更到 `openspec/changes/archive/2026-11-24-add-puremac-ui-redesign-and-lemon-research/`
- [x] 4.2 同步 `openspec/specs/system-cleaner/spec.md` 与 `openspec/specs/project-documentation/spec.md`（按 v3 实际实现改写信息架构 requirement）
- [x] 4.3 在 README / Docs 归档中补反向链接（调研文档关联变更路径已指向归档目录）
