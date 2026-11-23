# 任务：PureMac 模块（add-system-cleaner）

执行约定：本任务清单用于后续在 `feature/add-system-cleaner` 分支直接实施，完成后逐项勾选。验收项不通过不得勾选。

收尾规则（用户 2026-11-23 确认）：全部实施并完成第 9 节构建/固定签名/覆盖安装后，**停在 `feature/add-system-cleaner` 分支等用户真机验收**；用户确认合格后才合入 `main` 并 push。验收合格前不合并、不推送、不动远程 main。中途实施遇到歧义按 design.md / spec.md 与下方默认约定自行决策，不暂停询问用户；仅当触及范围外的新需求时才回头确认。

## 1. PureMac 精选源码移植（MIT）

- [x] 1.1 克隆上游到临时目录，逐文件复制白名单到 `Sources/MacAppControlDeck/Modules/SystemTool/UpstreamPureMac/`；每个文件顶部加来源与 MIT 版权头
- [x] 1.2 直接移植零/轻依赖文件：`FileSize.swift`、`Logger.swift`、`ProviderPaths.swift`、`OrphanSafetyPolicy.swift`、`FileProtection.swift`、`StringNormalization.swift`、`CleanupExclusions.swift`
- [x] 1.3 适配移植 `Models.swift`：只保留 `CleaningCategory` / `CleanableItem` / `CategoryResult` / `DiskInfo`，剔除调度与虚拟清理类型字段
- [x] 1.4 适配移植 `ScanEngine.swift`：只保留 systemJunk/userCache/largeFiles/trashBins/开发缓存分支，删除其余 9 个分类与 `NodeCacheManager`，改用本项目 Logger
- [x] 1.5 重写 `SystemTrashService.swift`（约 150 行）：从 `CleaningEngine` 提取"符号链接检查→解析后二次校验→trashItem 优先→失败再 removeItem"路径，不引入管理员提权与特殊清理
- [x] 1.6 整体移植 `DuplicateFinder.swift`（依赖 CryptoKit），日志替换为本项目 Logger，保留扫描上限
- [x] 1.7 移植 `AppPathFinder.swift` + 内联所需 `Locations` 路径常量，提供 `findPaths`/`findPathsAsync`
- [x] 1.8 移植 `ProcessResourceMonitor.swift`（Darwin + AppKit），仅作进程数据/图标源，不移植其 SwiftUI 视图
- [x] 1.9 移植 `DevToolCaches.swift`，适配 ProviderPaths/Logger
- [x] 1.10 写 `SystemPermissionGate`：只做 FDA 只读检测 + 打开系统设置跳转，无引导/演示视图
- [x] 1.11 MIT 许可全文追加到 `THIRD_PARTY_NOTICES.md`，列明上游 URL、许可证、引入方式（精选文件移植 + 薄适配）
- [x] 1.12 验收：`swift build --disable-sandbox` 通过；`grep -rn "killall\|sudo\|AuthorizationServices\|SMAppService" UpstreamPureMac/` 无结果；UpstreamPureMac 目录内无 `Views/` 或调度代码

## 2. 模块骨架与生命周期

- [x] 2.1 新建 `SystemToolModule.swift`：实现 FeatureModule，id `systemTool`，defaultEnabled true，supportsResidency false
- [x] 2.2 常驻 `SystemSampler`：2 秒定时采样 CPU/MEM 与进程列表，只读写系统 API；模块禁用/App 退出时停表并释放
- [x] 2.3 按需 `SystemScanPipeline`：扫描在 utility 队列执行，回主线程更新结果；扫描对象用完即弃，窗口关闭时取消
- [x] 2.4 新建 `SystemToolWindowController`（NSHostingController + NSWindow，autosave `SystemToolWindowFrame`，isReleasedWhenClosed=false，tabbingMode=.disallowed）
- [x] 2.5 `DeckApp.swift` 注册 `ModuleRegistry.shared.register(SystemToolModule.shared)`
- [x] 2.6 新增两个独立 `NSStatusItem`（仿柠檬截图分栏）：CPU 项用 `attributedTitle` 两行显示数值 + 标签 `CPU`，MEM 项两行显示占用百分比 + 标签 `MEM`；点击均直接 `open()` 不挂下拉菜单；与 `MenuBarController` 现有的聚合菜单状态项（当前 `A16`，调试残留）并存、互不改动；模块禁用时两个都移除。不显示温度/网速/音频图标
- [x] 2.7 状态栏展示信息设置：偏好键 `systemTool.menubar.showCPU` / `showMEM`（默认 true），设置页 systemTool tab 提供两个可单独勾选卡片，改动即时生效、不重建模块；不另设「菜单栏监控」总开关，模块启用开关即总闸；勾掉的项不创建对应状态项
- [x] 2.8 验收：启用模块后两个分栏状态项出现、定时器运行；分别勾掉 CPU/MEM 对应项立即消失、勾回立即出现；禁用模块后两个状态项消失、定时器停止、勾选状态保留；现有聚合菜单状态项及其下拉菜单始终不受影响；反复开关 5 次无泄漏、无崩溃

## 3. 内置入口、菜单与设置页

- [x] 3.1 `BuiltinActions.all` 增加 `systemTool.open`（name「打开 PureMac」，symbol「🧹」）；`run` switch 接 `SystemToolModule.shared.open()`
- [x] 3.2 `SystemToolModule.menuItems()` 提供「PureMac」父菜单 + `打开 PureMac…` / `PureMac 设置…` 子项
- [x] 3.3 `SettingsView.swift`：`SettingsTab` 增加 `case systemTool`；新增设置视图（扫描目录、大文件阈值、重复文件扫描根、排除路径管理、状态栏展示信息设置-CPU/MEM 可勾选卡片、模块说明）
- [x] 3.4 验收：从设置→按钮管理添加 `systemTool.open` 后，菜单栏「快捷操作」与手机面板快捷区都出现按钮，点击确实打开窗口（按 R0 验证到"点了能打开"）

## 4. 清理与卸载 UI

- [x] 4.1 概览页：磁盘概况 + 分类入口 + 一键扫描（扫描全部已实现分类）
- [x] 4.2 垃圾清理页：分类多选、结果列表（路径/大小/时间/分类）、默认不选中、选中总大小、清理确认（区分废纸篓/永久删除）、结果统计
- [x] 4.3 大文件页：阈值可调（默认 >100MB 或 >1 年）、结果默认不选中、确认后移废纸篓
- [x] 4.4 应用卸载页：应用列表 → 选中 → 扫描关联文件 → 高置信/需人工核对分组 → 只允许高置信批量勾选 → 确认后卸载并移残留入废纸篓
- [x] 4.5 排除路径管理（复用 `CleanupExclusions`），右键结果行可加入排除
- [x] 4.6 验收：构造临时目录测试文件，扫描结果默认全不选中；清理确认文案准确；勾选后文件确实进废纸篓（用 `ls ~/.Trash` 验证）；排除路径不再出现在结果中

## 5. 重复文件页

- [x] 5.1 扫描根选择（默认用户目录，可改）+ 启动/取消 + 进度
- [x] 5.2 分组展示（大小/文件数/可释放空间），keeper 标注"保留"，其余默认不选中
- [x] 5.3 勾选后确认移废纸篓，keeper 不受影响；达到扫描上限时显示提示
- [x] 5.4 验收：临时目录放 3 份同内容文件，扫描出 1 组、可释放 = 2×单文件大小；勾选 2 份确认后 keeper 仍在、2 份进废纸篓

## 6. 进程页与退出

- [x] 6.1 进程列表：图标 + 名称 + 内存占用，按内存/CPU 排序，搜索过滤，helper 归组到宿主应用
- [x] 6.2 每行退出/强制退出按钮；`terminate()` 优雅退出，`forceTerminate()` 单独二次确认
- [x] 6.3 系统/root/SIP 保护进程置灰 + "系统进程不可退出"标注，点击无动作
- [x] 6.4 验收：对一个自己启动的测试 App 点"退出"确实退出；对 Finder/系统进程按钮置灰；强制退出确认弹窗文案含"未保存内容会丢失"

## 7. 权限与FDA提示

- [x] 7.1 `SystemPermissionGate` 检测 FDA 状态，未授权时结果页顶部常驻提示"部分目录未授权，结果不完整" + 打开系统设置按钮
- [x] 7.2 授权后重扫，提示消失，原跳过目录纳入
- [x] 7.3 验收：在 FDA 未授权状态扫描，提示正确显示且不阻塞；点击跳转打开系统设置的"完全磁盘访问"面板

## 8. 测试

- [x] 8.1 新增单元测试：`SystemTrashService` 符号链接保护、排除路径、`DuplicateFinder` 哈希分组、`OrphanSafetyPolicy` 分级
- [x] 8.2 `DECK_RUN_ACTIVATION_E2E` 保持默认跳过（本变更不触及 `Control/AppControl.swift`）
- [x] 8.3 验收：`swift test --disable-sandbox` 全绿

## 9. 构建、签名与覆盖安装

- [x] 9.1 `swift build -c release --disable-sandbox` 通过（build.sh 缺参数时按既有等价流程处理，不改脚本）
- [x] 9.2 组装 .app、复制 bundle、生成图标，走 `source Build/signing.sh && deck_sign_app` 固定身份签名（**禁止 ad-hoc**）
- [x] 9.3 `./Build/verify-signing.sh BuildOutput/MacAppControlDeck.app` 通过，DR 为 certificate root
- [x] 9.4 `rsync -a --delete` 覆盖 `/Applications`，二进制哈希一致，安装后再次 `verify-signing.sh` 通过
- [x] 9.5 重启应用，确认菜单栏 PureMac 状态项与菜单出现；TCC 授权（辅助功能/输入监控/屏幕录制/自动化）不需重授
- [x] 9.6 验收：签名全程固定身份；`codesign -dv` 的 DR 不含 `cdhash` 单独形式

## 10. 文档与归档

- [x] 10.1 README 增加 PureMac 功能说明（注明清理引擎移植自 PureMac (MIT, momenbasel)），反向链接本变更 id `add-system-cleaner`
- [x] 10.2 主 spec 同步：把 `openspec/changes/add-system-cleaner/specs/system-cleaner/spec.md` 内容并入 `openspec/specs/system-cleaner/spec.md`
- [x] 10.3 `button-panel-config` spec 同步 `systemTool.open` 入口
- [x] 10.4 归档到 `openspec/changes/archive/2026-11-23-add-system-cleaner/`，任务全部勾选
- [x] 10.5 提交说明引用 change-id `add-system-cleaner`，写明新增用户可见入口 `systemTool.open`
