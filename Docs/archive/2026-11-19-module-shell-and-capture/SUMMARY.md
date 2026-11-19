# 2026-11-19 模块骨架与本机全屏截图（P0 + P1）总结

## 目标

把应用改造成“功能模块化”的形态，并接入第一个独立功能模块：Mac 本机截图/录屏。

本阶段只做：

- P0：模块协议、注册表、模块开关、统一设置壳、菜单按模块拼接
- P1：Mac 本机菜单栏「全屏截图」，使用 macshot 的 `ScreenCaptureManager` 引擎
- 不做：手机端截图/录屏、区域/窗口截图、标注、录屏、上传、翻译、全局热键

## 已确认的决策

1. **GPL-3.0**：接受。仓库根目录加入 `LICENSE`，并新增 `THIRD_PARTY_NOTICES.md`。
2. **设置统一**：不搬 macshot 的独立设置 App；使用本项目自己的 SwiftUI 设置窗口，按模块分区。
3. **范围**：先只保留截图 + 录屏；上传、翻译、全局热键暂不做。
4. **截图/录屏是本机功能**：不经过手机、不注册 HTTP 路由、不出现在手机面板。
5. **模块隔离**：`remote` 与 `capture` 各自拥有服务、数据、权限、生命周期，互不引用。

边界规则见 `Docs/architecture/MODULES.md`（强制约定）。

## 实现内容

### Core

- `Sources/MacAppControlDeck/Core/FeatureModule.swift`
  - 模块最小契约：`id/title/summary/systemImage/defaultEnabled/start/stop/menuItems/settingsView`
- `Sources/MacAppControlDeck/Core/ModuleRegistry.swift`
  - 模块注册、开关持久化（`module.enabled.<id>`）、启停、按启用状态拼菜单
  - 不持有任何模块业务对象

### 电脑遥控模块

- `Sources/MacAppControlDeck/Modules/RemoteControl/RemoteControlModule.swift`
  - 包住原有 `DeckState.start/stop`
  - 原有 HTTP 服务、配对、按钮、设备逻辑不变

### 截图与录屏模块

- `Sources/MacAppControlDeck/Modules/Capture/CaptureModule.swift`
  - 菜单「截图与录屏 → 全屏截图」
  - 检查/请求屏幕录制权限
  - 保存 PNG 到 `~/Pictures/MacAppControlDeck`（可改）
  - 复制到剪贴板
  - 非阻塞 toast + 系统提示音
  - 区域/窗口/录屏先显示为“下一阶段”禁用项
- `CapturePreferences.swift`：`capture.` 前缀偏好
- `CaptureSettingsView.swift`：输出目录、保存/复制开关、权限状态、测试按钮
- `CaptureToast.swift`：底部轻提示

### MacShotKit

- 新增独立 SwiftPM target `MacShotKit`（同进程，不是独立 App）
- 首期只引入：
  - `ScreenCaptureManager.swift`（macshot 截图引擎）
  - `MacShotCapture.swift`（对外最小 API）
- 为兼容当前 macOS 15，裁掉了 macshot 中仅 macOS 26 可用的 `SCScreenshotConfiguration` 代码路径
- `MacShotKit` 只能被 `capture` 模块 import

### UI / 菜单

- `MenuBarController`：
  - 关闭 `remote` 时隐藏面板/按钮/配对/重启，显示“电脑遥控已关闭”
  - 已启用模块各自贡献菜单；截图模块出现「截图与录屏」子菜单
- `SettingsView`：
  - 从 TabView 改为 `NavigationSplitView` 侧边栏
  - 分区：应用 / 模块 / 电脑遥控（按钮、设备）/ 截图与录屏 / 关于
  - 「模块」页提供独立开关；开启截图后可跳到截图设置

## 隔离验证

- `capture` / `MacShotKit` 中无 `DeckState` / `ConfigStore` / `PairingManager` / `APIRouter` / `PanelHTML` 引用
- `remote` / `Server` / `Store` 中无 `MacShotKit` / `CapturePreferences` / `CaptureModule` 引用
- `APIRouter` 未新增任何截图/录屏路由
- 手机面板未新增截图/录屏入口
- 关闭 `remote` 只停 HTTP 服务；关闭 `capture` 只停菜单入口，不影响遥控

## 验证结果

- `swift build`：通过（仅 macshot `CGWindowListCreateImage` 的废弃警告）
- `swift test`：38 个测试全部通过
- `./Build/build.sh`：release 构建 + 自签名通过
- 安装到 `/Applications/MacAppControlDeck.app`，启动正常
- `/api/health` 返回 `{"app":"MacAppControlDeck","ok":true,"version":"0.1.0"}`
- 菜单栏实测：
  - 「面板 / 应用 / 配对手机 / 重启服务 / 截图与录屏 / 设置 / 退出」
  - 「截图与录屏」子菜单：全屏截图、区域/窗口/录屏（下一阶段，禁用）
- 点击「全屏截图」触发系统「屏幕录制」授权页，说明 TCC 链路已接通

## 已知限制 / 下一步

1. 屏幕录制权限需用户在「系统设置 → 隐私与安全 → 屏幕录制」中勾选本应用，并重启应用后生效。
2. 当前只有主屏全屏截图；区域/窗口/多屏/延时/标注/历史/钉图未接入。
3. 录屏（MP4/GIF、音频、麦克风、摄像头、视频编辑）未接入，菜单显示为下一阶段。
4. macshot 的 Overlay/Editor 代码量大，下一步按 P2 逐步移植，并解决 `NSApp.delegate` 耦合。
5. 本轮改动尚未 git 提交；提交前需确认是否与菜单栏重构改动一起提交。
