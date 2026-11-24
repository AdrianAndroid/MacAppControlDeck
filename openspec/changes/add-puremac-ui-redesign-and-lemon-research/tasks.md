# 任务：PureMac UI 重做与柠檬调研记录

执行约定：本次只做文档与证据沉淀，触及 `Sources/` 的 UI 实施留到回家后再开始。完成一项勾一项。

## 1. 文档与证据（已完成）

- [x] 1.1 新增 `Docs/plans/2026-11-24-puremac-ui-redesign.md`：现状诊断、参考取舍、14 组 ASCII 图、Token、落地映射
- [x] 1.2 新增 `Docs/research/2026-11-24-tencent-lemon.md`：功能地图、已收集证据、后台/前台操作路径、命令与坐标、待办 checklist
- [x] 1.3 归档 6 张柠檬真机截图到 `Docs/research/tencent-lemon/screenshots/`
- [x] 1.4 归档截图与点击脚本到 `Docs/research/tencent-lemon/tools/`
- [x] 1.5 建立 OpenSpec 变更，补 `system-cleaner` 与 `project-documentation` 的 delta

## 2. UI 实施（回家后）

- [ ] 2.1 新增 `SystemToolShell.swift`：`Sidebar` / `PageHeader` / `FilterStrip` / `SummaryBar` / `Badge` / `Chip`
- [ ] 2.2 `SystemToolRootView` 改为「左轨 + 内容 + 统一 StatusBar」，移除顶部 tab
- [ ] 2.3 概览页：磁盘主卡 + 6 张分类卡 2 列（≥900pt 3 列），未扫描态弱化
- [ ] 2.4 垃圾清理页：分类 chip、分组头、统一表格与 SummaryBar，删除重复标题/统计/脚注
- [ ] 2.5 应用卸载页：左列 220pt + 搜索框，右列分组标题精简
- [ ] 2.6 大文件页：筛选条件卡片改为单行 FilterStrip
- [ ] 2.7 重复文件页：keeper 「保留」徽标且不可勾选，跳过项折叠
- [ ] 2.8 进程页：采样状态、搜索、排序合并进 PageHeader，统一表头
- [ ] 2.9 `SystemToolComponents` 行高 44、字号与间距 token 对齐设计稿
- [ ] 2.10 640 / 720 / 900 三档真机截图验收；`swift build` 与 `SystemToolTests` 全绿

## 3. 柠檬调研补全（回家后）

- [ ] 3.1 隐私清理：入口页 + 扫描结果
- [ ] 3.2 开机启动项管理：列表与开关态
- [ ] 3.3 磁盘空间分析：扫描结果与分类视图
- [ ] 3.4 柠檬精选：页面结构
- [ ] 3.5 相似照片：添加文件夹 → 扫描结果 → 分组
- [ ] 3.6 重复文件：添加文件夹 → 扫描结果 → 分组
- [ ] 3.7 应用卸载详情：关联文件/残留列表
- [ ] 3.8 首页「开始扫描」的智能扫描结果页
- [ ] 3.9 菜单栏状态项与设置页（若存在）
- [ ] 3.10 补全调研文档的对比表与结论

## 4. 收尾

- [ ] 4.1 全部完成后归档变更到 `openspec/changes/archive/YYYY-MM-DD-add-puremac-ui-redesign-and-lemon-research/`
- [ ] 4.2 同步 `openspec/specs/system-cleaner/spec.md` 与 `openspec/specs/project-documentation/spec.md`
- [ ] 4.3 在 README 或 Docs 归档中补反向链接
