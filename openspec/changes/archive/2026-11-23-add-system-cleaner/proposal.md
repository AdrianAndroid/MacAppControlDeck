# 提案：新增 PureMac 模块（清理 / 卸载 / 监控）

## Why

用户希望在本项目内替代腾讯柠檬的核心实用功能。柠檬是闭源商业软件，功能覆盖清理、卸载、磁盘分析、状态栏监控，但无法按本项目的固定签名、TCC 授权和快捷入口规则集成。开源方案中 PureMac（MIT）覆盖了清理主干且许可证兼容本项目的 GPL-3.0 分发，WonderBox 补足进程/内存展示但许可证未明、只能参考。需要一个自研的、单一 FeatureModule 承载的 PureMac 模块，把清理主干做成本项目的一个原生 SwiftUI 功能，而不是引入第二个独立 App。模块的**用户可见显示名沿用上游项目名 PureMac**（用户于 2026-11-23 指定，理由是清理引擎复用该项目），代码标识符仍用 `systemTool` / `SystemToolModule` 保持不变；上游 MIT 版权头与许可全文照常保留并追加到 `THIRD_PARTY_NOTICES.md`，模块说明页注明"清理引擎移植自 PureMac (MIT, momenbasel)"。

## What Changes

- 新增单一 `SystemToolModule`（id `systemTool`），以一个设置页 Tab、一个菜单分组和一个原生 SwiftUI 窗口承载全部子功能；模块内部把"常驻采样"与"按需扫描"拆成两条独立服务对象，避免生命周期互相牵制，但不新增第二个 FeatureModule。
- 从 PureMac 精选移植 MIT 许可的底层工具与引擎文件到 `Sources/MacAppControlDeck/Modules/SystemTool/UpstreamPureMac/`，逐文件加版权头；不移植其 App 外壳、菜单栏、更新、调度、相似照片、保护审计。
- 第一版交付 6 项能力：垃圾/缓存清理、应用卸载+残留、大文件清理、重复文件清理、菜单栏 CPU/MEM、应用列表+退出/强退。
- 安全模型：清理前展示具体路径与大小；默认不自动删除；优先移废纸篓；`terminate()` 优雅退出、`forceTerminate()` 带二次确认；系统/root/SIP 保护进程置灰不可操作。
- 完全磁盘访问按需申请：未授权时扫描可访问范围并明确标注结果不完整，不强制一上来授权。
- 内置打开入口 `systemTool.open`，可在设置→按钮管理添加，自动进入菜单栏「快捷操作」与手机面板快捷区。
- Info.plist 不新增权限描述键（本模块不申请新权限；完全磁盘访问由用户在系统设置手动授予，无 UsageDescription 要求）。
- 签名、Bundle ID、runtime 标志、TCC 授权范围一律不变；不引入特权 helper，不请求管理员授权。

**非目标**：

- 不做内存一键释放（需特权 helper + 管理员授权，可能破坏现有 TCC 授权，且收益存疑）；改为"应用列表 + 退出/强退"替代截图里的"释放"按钮。
- 不做温度/风扇读数（SMC 私有 API、纯展示、App Store 分发受限）。
- 不做磁盘空间可视化、启动项管理（放第二期）。
- 不做相似照片、网络测速曲线、隐私清理与摄像头/音频监控、柠檬精选。
- 不引入柠檬（GPL-3.0）、Mole、Pearcleaner、WonderBox 的任何源码；WonderBox 仅作功能参考。
- 不修改 `Build/signing.sh`、`Build/Info.plist` 的签名相关键，不改变稳定签名身份。

## Capabilities

### New Capabilities

- `system-cleaner`：系统清理、应用卸载与残留、大文件、重复文件、进程监控与退出的能力契约与安全规则。

### Modified Capabilities

- `button-panel-config`：新增内置操作 `systemTool.open`。

## Impact

- 代码：新增 `Sources/MacAppControlDeck/Modules/SystemTool/`（模块、窗口、视图、服务、PureMac 移植目录）；修改 `Core/FeatureModule` 消费方（`DeckApp.swift` 注册、`BuiltinActions.swift` 入口、`SettingsView.swift` Tab）。
- 依赖：不新增 SwiftPM 包；PureMac 的 `DuplicateFinder` 依赖 CryptoKit（系统框架），`ProcessResourceMonitor` 依赖 Darwin（系统库）。
- 许可证：新增 MIT 版权归属，追加到 `THIRD_PARTY_NOTICES.md`；MIT 代码并入 GPL-3.0 项目方向兼容，保留原版权头与许可全文。
- 权限：不新增 Info.plist UsageDescription；完全磁盘访问由用户按需在系统设置授予。
- 风险：清理/卸载/强退均是不可逆或可致数据丢失的操作，必须严格按 spec 的安全场景实现与验收。
