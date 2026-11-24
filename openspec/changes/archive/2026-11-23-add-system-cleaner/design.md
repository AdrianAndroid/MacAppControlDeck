# 设计：单模块 PureMac（SystemToolModule）

## 1. 模块结构与生命周期

采用**单一 FeatureModule**，遵守 `Core/FeatureModule.swift` 契约（id/title/summary/systemImage/defaultEnabled/start/stop/menuItems/settingsView + residency 相关默认实现）。模块 id 固定 `systemTool`，APP 域偏好键 `module.enabled.systemTool` 由 `ModuleRegistry` 统一管理。

模块内部强制拆成两条互不影响的服务路径，但它们同属一个模块外壳：

- **常驻路径 `SystemSampler`**：菜单栏 CPU/MEM 采样 + 进程列表读取。只在模块启用时启动一个 2 秒定时器，采样用 system API（host_statistics64 / proc_listallpids / task_info 之类，只读），窗口关闭不停；模块禁用时停定时器并释放。窗口未打开但模块启用时仍采样（菜单栏要显示）。
- **按需路径 `SystemScanPipeline`**：垃圾/缓存、大文件、重复文件、卸载残留扫描。只在用户点「扫描」时构造，扫描在 `DispatchQueue.global(qos: .utility)` 上跑，结果回主线程；扫描对象不常驻内存，扫描结束或窗口关闭即释放。清理/卸载/强退动作也走这条路径，且都要求 UI 二次确认。

两条路径不共享可变状态；进程列表数据从 `SystemSampler` 读快照，清理结果从 `SystemScanPipeline` 读，互不写对方。

窗口用 `NSWindowController` + `NSHostingController`，遵循 `Modules/Calendar/CalendarWindowController.swift` 的惯例：`isReleasedWhenClosed = false`、`setFrameAutosaveName`、`tabbingMode = .disallowed`、@MainActor、由 runtime 持有、关闭回调里按需释放。`defaultEnabled = true`，`supportsResidency = false`（用模块自身的 enabled 开关控制菜单栏采样）。

## 2. PureMac 移植清单（精选文件 + LICENSE）

上游：`https://github.com/momenbasel/PureMac`，MIT License，Copyright (c) 2026 PureMac Contributors。克隆到临时目录后按下列白名单逐个复制，每个文件顶部加注释块说明来源与 MIT 许可，并把 MIT 全文追加到 `THIRD_PARTY_NOTICES.md`。

目标目录：`Sources/MacAppControlDeck/Modules/SystemTool/UpstreamPureMac/`

**直接移植（零依赖或仅 Foundation，可直接编译）**：

| 上游文件 | 用途 | 依赖 |
|---|---|---|
| `Logic/Utilities/FileSize.swift` | 字节格式化 | 无 |
| `Logic/Utilities/Logger.swift` | 轻量日志 | 无 |
| `Logic/Utilities/ProviderPaths.swift` | 应用容器路径解析 | Foundation |
| `Logic/Utilities/OrphanSafetyPolicy.swift` | 卸载残留删除前的安全判定 | Foundation |
| `Logic/Utilities/FileProtection.swift` | 符号链接/系统路径保护判定 | Foundation |
| `Logic/Scanning/StringNormalization.swift` | 名称归一化 | Foundation |
| `Services/CleanupExclusions.swift` | 排除路径（UserDefaults） | Foundation |

**需要适配后移植**：

| 上游文件 | 用途 | 适配动作 |
|---|---|---|
| `Models/Models.swift` | `CleaningCategory` / `CleanableItem` / `CategoryResult` / `DiskInfo` | 只保留这 4 个类型；删除 `ScheduleConfig`、`ScheduleInterval`、`ScanState` 中与调度/全应用状态耦合的字段；`CleanableItem` 移除 `selectOnlyByHand` 之外与虚拟项（simctl/docker/language/universal binary）相关的字段，避免把第一版不做的清理类型带进来 |
| `Services/ScanEngine.swift` | 分类扫描 | 1527 行，只保留 `scanCategory` 的 `.systemJunk` / `.userCache` / `.largeFiles` / `.trashBins` / 开发缓存相关分支及其私有扫描函数；删除 `.smartScan` / `.purgeableSpace` / `.universalBinaries` / `.languageFiles` / `.aiApps` / `.mailAttachments` / `.dockerCache` / `.rustTargets` / `.nodeModules` 分支和 `NodeCacheManager`；改用本项目 `Logger`，保留 `onPath` 回调签名 |
| `Services/CleaningEngine.swift` | 清理执行 | 1242 行，**不整文件移植**。提取 `CleaningResult` 结构与 `deleteFilesystemItem` 的"符号链接检查 → 解析后二次校验 → FileManager.trashItem 优先 → 失败再 removeItem"核心路径，重写为约 150 行的 `SystemTrashService`；删除 purgeable space / 二进制瘦身 / 语言文件 / Docker prune / cargo clean / simctl / 管理员提权 / XcodeBuildMCP 全部逻辑 |
| `Services/DuplicateFinder.swift` | 重复文件 SHA-256 分组 | 501 行，依赖 CryptoKit（系统框架）。整体移植，保留 `scan`、`moveToTrash`、`DuplicateSkipReason`、`isDatalessFile`；把日志调用替换为本项目 `Logger`；扫描上限沿用上游（每次 500 文件 / 10000 目录项）并在 UI 提示 |
| `Logic/Scanning/AppPathFinder.swift` | 应用发现与路径 | 393 行，依赖 `Locations`；移植 `findPaths` / `findPathsAsync`，把 `Locations` 中本模块用到的路径常量内联，不引入整个扫描子系统 |
| `Services/FullDiskAccessManager.swift` | FDA 状态检测 | 只取"检测是否已授权"的只读判断（列举受保护目录并尝试读），移植为 `SystemPermissionGate`；删除引导页/演示视图/跳转逻辑，跳转用本项目 `NSWorkspace.open` 到系统设置对应 pane |
| `Services/ProcessResourceMonitor.swift` | 进程采样 | 256 行，依赖 Darwin + AppKit。整体移植用于进程列表数据源（名称、residentBytes、图标、helper 归组、CPU 分数）；窗口/菜单栏展示由本项目视图实现，不移植其 SwiftUI 视图 |
| `Logic/Utilities/DevToolCaches.swift` | 开发缓存路径 | 205 行，依赖 `ProviderPaths` / `Logger`，直接移植 |

**明确不移植**：`Views/**`、`ViewModels/**`、`Services/SchedulerService.swift`、`Services/ApplicationUpdater.swift`、`Services/UpdateService.swift`、`Services/ProtectionAudit.swift`、`Services/BinaryThinner.swift`、`Services/SimilarPhotoFinder.swift`、`Services/AppleStorageService.swift`、`Services/DeviceBackupService.swift`、`Services/Haptics.swift`、`Services/CleanupExclusions` 之外的 UI 层。

**命名冲突检查已完成**：本项目内 `Logger` / `FileSize` / `ProviderPaths` / `CleaningCategory` / `CleanableItem` / `DiskInfo` / `DuplicateFinder` / `FullDiskAccessManager` 均无同名类型。为降低未来冲突，移植文件统一放在 `UpstreamPureMac/` 子目录并保留原类型名，不做前缀重命名（便于对照上游与升级）。

## 3. 功能到实现的映射

| 功能 | 实现 |
|---|---|
| 垃圾/缓存清理 | `ScanEngine.scanCategory(.systemJunk/.userCache/开发缓存)` → `CleanableItem` 列表（路径+大小+时间，默认 `isSelected = false`）→ `SystemTrashService` 删除 |
| 应用卸载 + 残留 | `AppPathFinder.findPaths()` 列出已安装应用 → 选中应用后按 bundle ID + `ProviderPaths` + `OrphanSafetyPolicy` 扫关联文件 → 分级展示（高置信/需核对）→ 确认后移废纸篓 |
| 大文件清理 | `ScanEngine.scanCategory(.largeFiles)`，阈值默认 >100MB 或 >1 年，UI 可调；结果默认不选中 |
| 重复文件清理 | `DuplicateFinder.scan(folder:)` → `DuplicateGroup`，每组 `keeper` 保留，其余默认不选中，确认后 `moveToTrash` |
| 菜单栏 CPU/MEM | `SystemSampler` 2 秒采样，菜单栏**两个独立 `NSStatusItem`** 分栏显示：CPU 项上数值下标签 `CPU`，MEM 项上数值下标签 `MEM`（仿柠檬截图分栏形态）；点击打开窗口；只读、不需要 TCC 授权。温度/网速不加回 |
| 应用列表 + 退出/强退 | `ProcessResourceMonitor` 提供进程快照与图标 → 列表显示名称/内存/resident；`terminate()` 与 `forceTerminate()`；系统/root/SIP 进程用 `ProcessResourceMonitor` 的可访问性判断置灰并标注 |

## 4. 安全规则（必须落到代码与 UI）

1. **默认不删**：所有 `CleanableItem` / `DuplicateGroup` / 卸载残留项 `isSelected = false`；没有"全选后直接删"的隐式路径。
2. **先看后删**：任何删除前必须有一个展示具体路径、大小、类别的确认步骤；确认文案区分"移入废纸篓"与"永久删除"。
3. **废纸篓优先**：`SystemTrashService` 先 `FileManager.trashItem`，只有失败且用户明确勾选"永久删除"时才 `removeItem`；永久删除必须单独二次确认。
4. **符号链接与系统路径保护**：删除前 `resolvingSymlinksInPath()`，校验**原始路径与解析后路径都**在允许范围；命中 `FileProtection` 保护规则则跳过并在结果里计入 `skippedPaths`，UI 显示跳过数量。
   - **允许范围必须与扫描范围同源**（2026-11-24 复核修正）：`SystemToolScanRoots.swift` 是「`ScanEngine` 扫哪里」与「`SystemTrashService` 允许清哪里」的唯一定义，`ScanEngine.largeFileRoots()` 直接复用。初版把卸载残留的 `OrphanSafetyPolicy.allowedRoots`（仅缓存/日志）误用作通用清理白名单，导致大文件、开发缓存、Xcode 缓存、沙盒容器缓存等扫描结果在用户确认后被静默跳过、清理结果恒为 0 项；已由临时探针实证并修复。
   - denylist 优先于 allowlist：`/System`、`/usr/bin`、`/etc`、`~/.ssh`、`~/.gnupg`、`~/Library/Keychains`、`~/Library/Preferences` 等系统关键与凭据路径一律拒绝，不因允许范围放宽而失效。逐项精确到子目录，避免误伤明确列入的开发缓存根（如 `~/.local/share/pnpm`）。
   - 重复文件与应用卸载是独立链路，不经 `SystemTrashService.clean`：前者用 inode 身份 + SHA-256 复核 + keeper 保留，后者用 `removeResiduals` 的独立允许根，两者都直接移入废纸篓。
5. **卸载残留分级**：`OrphanSafetyPolicy` 判定为高置信的直接列出；低置信的标"需人工核对"，不允许批量勾选删除。
6. **强退保护**：`forceTerminate()` 只对 `isTerminationAllowed` 的进程启用；系统进程、root 进程、SIP 保护进程置灰并显示"系统进程不可退出"；`forceTerminate` 单独弹确认，写明"未保存内容会丢失"。
7. **FDA 未完成标注**：`SystemPermissionGate` 检测无完全磁盘访问时，扫描照常进行，但结果页顶部常驻黄色提示"部分目录未授权，结果不完整"，并给"打开系统设置"按钮；不阻断扫描。
8. **扫描可取消**：任何扫描提供取消，取消后不产生删除动作；扫描期间 UI 显示进度，不冻结。

## 5. 入口与 UI

- 内置操作：`BuiltinActions.all` 增加 `Preset(id: "systemTool.open", name: "打开 PureMac", symbol: "🧹")`，`run` 的 switch 增加 `case "systemTool.open": SystemToolModule.shared.open()`。按项目 R0，此入口在「设置→按钮管理→添加内置操作」中可选择；被添加为按钮后进入菜单栏「快捷操作」子菜单与手机面板快捷区。模块自身的菜单里另有 `打开 PureMac…`（`systemTool.open`）常驻入口，不依赖用户配置。
- 模块菜单：`menuItems()` 返回单个父菜单「PureMac」，子项含 `打开 PureMac…`（id `systemTool.open`）、`PureMac 设置…`（id `systemTool.settings`）；不注册全局快捷键（非高频）。
- 设置页：`SettingsTab` 增加 `case systemTool`，`SettingsView` 增加对应 tab 视图（扫描目录、大文件阈值、重复文件扫描根、排除路径管理、**状态栏展示信息设置**、模块说明）。
  - 状态栏展示信息设置：仿柠檬偏好设置，提供 CPU、MEM 两个可单独勾选的卡片（默认都勾选），偏好键 `systemTool.menubar.showCPU` / `systemTool.menubar.showMEM`，改动即时生效、无需重启。只控制这两个状态项各自的显示，**不是总开关**——总开关是架构自带的 `FeatureModule.enabled`（设置 → 模块 → PureMac）。模块禁用时两状态项一并消失，勾选状态保留；重新启用后按勾选恢复。
  - 不引入柠檬截图里的「打开主界面时显示状态栏」「开机时显示状态栏」两个开关（前者本项目无对应概念，后者由模块启用持久化覆盖）。
- 窗口：`SystemToolWindowController`（720×640，可调整，autosave name `SystemToolWindowFrame`），内部 `TabView` 六个页签：概览、垃圾清理、应用卸载、大文件、重复文件、进程。
- 菜单栏：**新增两个独立 `NSStatusItem`**（不改动 `MenuBarController` 现有的那个状态项，三者并存），仿柠檬截图的分栏形态：
  - CPU 项：`button.attributedTitle` 两行——上行为数值（如 `11%`，较大字号），下行为标签 `CPU`（较小字号、次要色）。
  - MEM 项：同样两行——上行为占用百分比（如 `63%`），下行为标签 `MEM`。
  - 两项都只在 PureMac 模块启用时存在，2 秒随 `SystemSampler` 更新；点击均直接调用 `SystemToolModule.shared.open()` 打开窗口，不挂下拉菜单；模块禁用时一并移除。
  - 两项各自受设置页的可单独勾选控制（`showCPU` / `showMEM`），勾掉即不创建对应状态项；不另设「菜单栏监控」总开关，模块启用开关即总闸。
  - 温度、网速上下行、音频设备图标**不加回**（用户已确认保持砍掉状态）。
  - 现有聚合菜单状态项（当前显示 `A16`，是 `button.title = "A\(menu.items.count)"` 的调试残留）及其下拉菜单保持原样，本变更不碰。
  - 此分栏形态已由用户于 2026-11-23 确认。

## 6. 权限与签名

- 不申请新权限：`Info.plist` 不加任何 UsageDescription 键；完全磁盘访问由用户在系统设置→隐私与安全性→完全磁盘访问手动勾选本项目 App。
- 不引入 privileged helper、不请求管理员授权（明确排除内存释放方案）。
- 固定签名、Bundle ID、`Build/signing.sh`、`Build/verify-signing.sh` 一律不改；构建与覆盖安装沿用 `./Build/build.sh`（swift build 缺 `--disable-sandbox` 时按既有等价流程补该参数）；覆盖安装后跑 `verify-signing.sh`，确认 DR 仍是 certificate root，TCC 授权不重置。
- CryptoKit / Darwin 均为系统框架，不新增 SwiftPM package，Package.swift 的 dependencies 不变。

## 7. 与现有架构的遵循与隔离

### 7.1 逐条遵循项目规则（R0/R1/R2/R3 + FeatureModule 契约）

| 规则 | 本变更的遵循方式 |
|---|---|
| R0 内置快捷入口 | `systemTool.open` 进 `BuiltinActions.all` 与 `run` switch；由用户从按钮管理添加后进入菜单栏「快捷操作」和手机面板；模块菜单自身另有常驻「打开 PureMac…」。提交前验证"添加后点击确实打开窗口"。 |
| R1 OpenSpec | 本变更目录即 `add-system-cleaner`，含 proposal/design/tasks/spec delta；归档后同步主 spec；提交说明引用 change-id。 |
| R2 固定签名 | 不改 signing.sh、Bundle ID、runtime 标志；固定身份签名 + verify-signing.sh；DR 保持 certificate root。 |
| R3 不重复验证打开应用 | 本变更不触及 `Control/AppControl.swift`、`QuickActionRunner` 的 app 分支、`DeckState.perform` 的激活逻辑、`/api/activate`；不跑激活 E2E。 |
| FeatureModule 契约 | 实现 id/title/summary/systemImage/defaultEnabled/start/stop/menuItems/settingsView；residency 用默认实现（supportsResidency=false）。 |

### 7.2 隔离机制：新模块不响应、不干扰其它功能

代码级隔离点（均已核对现有实现）：

1. **模块开关门控**：`MenuCustomization.orderedModules` 只返回 `isEnabled` 的模块（已读源码确认）；`ModuleRegistry.setEnabled` 才触发 `start/stop`。新模块禁用时菜单不出现、定时器不启动、内置按钮即使存在点击也因 `open()` 内守卫而无效。实现时 `SystemToolModule.open()` 与状态项回调都要先检查 `ModuleRegistry.shared.isEnabled("systemTool")`。
2. **菜单空间隔离**：`MenuBarController.rebuild()` 遍历各模块的 `menuItems()`，新模块只返回自己 id 前缀的项（如 `systemTool.open` / `systemTool.settings`），不修改也不读取其它模块的菜单项；置顶/隐藏由 `MenuCustomization` 按 moduleID 管理，不会串到其它模块。
3. **执行链隔离**：`BuiltinActions.run` 的 switch 加一个独立 case，不改 `QuickActionRunner` 的 `.app/.shortcut/.command` 分支；内置动作在 `DispatchQueue.main.async` 里执行，与 `.shortcut/.command` 用的 `queue.sync` 串行队列不共享，不会互相阻塞。扫描/清理另起 utility 队列，不占 QuickActionRunner 的队列。
4. **输入监听隔离**：项目只有 `Modules/Pet/PetInputMonitor.swift` 注册全局事件监听（已确认）；PureMac **不注册任何 CGEvent tap 或 NSEvent 全局监听**，因此不会抢走桌宠的按键/鼠标事件，也不会被快捷键误触。进程退出只对 `NSRunningApplication` 操作，不注入按键。
5. **权限隔离**：不调用 `AXIsProcessTrusted` / `CGRequestPostEventAccess` / `SMAppService`（已确认这些只在 `DeckState`/`AppControl`/`KeyInjector`/`SettingsView` 使用）；不新增 TCC 授权请求，完全磁盘访问由用户手动在系统设置授予，不影响现有辅助功能/输入监控/屏幕录制/自动化四项授权。
6. **数据与偏好隔离**：新模块偏好用独立键前缀 `systemTool.*`（超时、阈值、扫描根、排除路径），不复用其它模块的 UserDefaults 键；`CleanupExclusions` 虽移植自上游，但存储键加 `systemTool.` 前缀，避免与任何现有配置冲突。
7. **窗口隔离**：`SystemToolWindowController` 持有自己的窗口与 autosave name `SystemToolWindowFrame`，不复用日历/草图窗口；`setFrameAutosaveName` 独立，关闭只释放自己的 runtime。
8. **资源隔离**：常驻采样 2 秒一次、只读系统 API、CPU 开销可忽略；扫描与清理用完即释放；模块禁用后无残留定时器、无残留 statusItem。任何扫描都提供取消，取消后不产生删除。

### 7.3 验证隔离的验收动作

- 启用/禁用 PureMac 各 5 次，确认其它模块的菜单项、桌宠输入响应、快捷键、截图、副屏、遥控 HTTP 服务行为不变。
- PureMac 扫描/清理进行中，点菜单栏其它按钮（打开应用、快捷键、截图）仍即时响应（扫描在 utility 队列，不占主线程与 QuickActionRunner）。
- 打字与鼠标点击时桌宠照常有反馈（PureMac 未注册事件监听，不抢事件）。
- PureMac 启用期间不出现新的系统权限弹窗；现有 TCC 四项授权状态不变。

## 8. 测试策略

- 单元测试（`Tests/MacAppControlDeckTests/`）：`SystemTrashService` 的符号链接保护、排除路径、`DuplicateFinder` 哈希分组的正确性（用临时目录构造重复文件）；`OrphanSafetyPolicy` 分级判定。
- 手工验证（真机）：见 tasks.md 验收项；按 R3，「打开应用」的启动/激活跨桌面流水线不重复验证，除非改动触及 `Control/AppControl.swift` 等例外文件（本变更不触及）。
