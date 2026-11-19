# 模块边界与隔离规则

> 状态：强制约定（2026-11-19 起生效）
> 适用范围：`MacAppControlDeck` 全部代码、菜单、设置、路由、数据目录、文档
> 核心原则：**每个功能是一个独立模块；模块自己的服务、数据、权限、生命周期自己管；模块之间不共享业务状态，不互相调用，不混内容。**

## 1. 当前的两个模块

| 模块 | ID | 形态 | 使用者 | 入口 |
|---|---|---|---|---|
| 电脑遥控 | `remote` | 局域网 HTTP 服务 + 配对 + 手机面板 | 手机 | 菜单栏「面板 / 按钮 / 配对」、手机浏览器 |
| 截图与录屏 | `capture` | Mac 本机 AppKit 能力（截图 / 标注 / 录屏 / 编辑器） | Mac 本机 | 菜单栏「截图与录屏」、本机窗口 |

### 1.1 电脑遥控模块（`remote`）

负责：

- `NWListener` HTTP 服务（默认 47615）
- 设备配对、token、设备撤销
- 按钮配置（应用 / 快捷键 / 命令）
- 手机面板 HTML、图标、`/api/*`
- 应用激活、快捷键注入、命令执行

不负责：

- 截图、录屏、标注、OCR、图片历史
- 屏幕录制权限、麦克风/摄像头权限
- MacShotKit / macshot 代码

### 1.2 截图与录屏模块（`capture`）

负责：

- Mac 本机截图、区域/窗口/全屏/多屏/延时/滚动
- 标注编辑器、打码、美化、滤镜、钉图、历史
- 录屏 MP4/GIF、音频/麦克风/摄像头、视频编辑器
- 屏幕录制、麦克风、摄像头权限

不负责：

- 手机配对、HTTP 服务、手机面板
- 手机端触发截图/录屏
- 设备 token、按钮配置、应用激活

> **明确结论：截图/录屏是 Mac 本机功能，不是手机功能。手机面板不出现截图/录屏入口，`capture` 模块也不注册任何 `/api/*` 路由。**

## 2. 硬规则（后续开发必须遵守）

### R1. 模块目录隔离

```
Sources/MacAppControlDeck/
  Core/                         # 只放模块协议、注册表、菜单/设置壳
  Modules/
    RemoteControl/              # 只放 remote 模块代码
    Capture/                    # 只放 capture 模块代码
Sources/MacShotKit/             # macshot 上游代码，只允许 Capture 模块 import
```

- `RemoteControl` 不得 `import MacShotKit`。
- `Capture` 不得引用 `ConfigStore`、`PairingManager`、`DeviceRecord`、`APIRouter`、`PanelHTML`。
- `Core` 不得包含任一模块的业务逻辑；只提供协议、注册、菜单拼接、设置容器。

### R2. 服务隔离

- `remote` 的 HTTP 服务、端口、监听生命周期只属于 `remote` 模块。
- `capture` 不启动任何网络服务，不注册任何 HTTP 路由。
- 关闭 `remote` 模块必须只停 HTTP 服务，不得影响截图/录屏。
- 关闭 `capture` 模块必须只停截图/录屏能力，不得影响手机遥控。
- 不允许把截图/录屏接口塞进 `APIRouter`，也不允许手机面板调用本机截图。

### R3. 状态隔离

- `remote` 的状态只放在 `DeckState` / `ConfigStore` / `PairingManager`。
- `capture` 的状态只放在 `CapturePreferences` / `CaptureModule` / MacShotKit 自己的运行时。
- `Capture` 不得读写 `DeckState.shared`。
- `RemoteControl` 不得读写 `CapturePreferences.shared`。
- 两个模块之间只能通过 `Core` 的只读元数据（模块 ID、开关状态）通信，不传递业务对象。

### R4. 数据目录隔离

| 模块 | 目录 | UserDefaults 前缀 |
|---|---|---|
| `remote` | `~/Library/Application Support/MacAppControlDeck/RemoteControl/` | `remote.` |
| `capture` | `~/Library/Application Support/MacAppControlDeck/Capture/` | `capture.` |

- 截图历史、录制文件、导出缓存只能落在 `capture` 目录。
- 设备 token、按钮配置、图标缓存只能落在 `remote` 目录。
- 不允许两个模块共用同一个历史目录或同一个 `devices.json` / `buttons.json`。

### R5. 权限隔离

| 模块 | 需要的权限 |
|---|---|
| `remote` | 辅助功能、输入监控、自动化（System Events） |
| `capture` | 屏幕录制、麦克风、摄像头（按功能启用） |

- 权限状态分别展示在各自模块的设置页，不合并成一个“总权限”。
- 未授予截图权限时，只禁用截图/录屏功能，不影响手机遥控。
- 未授予辅助功能时，只影响跨桌面快捷操作，不影响截图。

### R6. 菜单与设置是“壳”，不是混合层

- 菜单栏由 `Core` 的 `ModuleRegistry` 按模块拼接；每个模块只贡献自己的 `NSMenuItem`。
- 设置窗口统一样式，但左侧导航按模块分区：
  - 通用（应用级）
  - 模块（模块开关）
  - 电脑遥控（remote 自己的设置）
  - 截图与录屏（capture 自己的设置）
  - 设备 / 关于
- 不允许在“通用”页里塞截图选项，也不允许在“截图”页里塞手机配对。
- 设置壳只负责承载视图，不替模块执行业务动作。

### R7. 依赖方向

```
Core  ←  Modules/RemoteControl
Core  ←  Modules/Capture → MacShotKit
```

- 只允许模块依赖 Core，不允许 Core 反向依赖具体模块。
- 只允许 `Capture` 依赖 `MacShotKit`。
- 模块之间禁止互相 import。

### R8. 失败隔离

- 截图/录屏失败（权限、显示器休眠、编码失败）只提示本机，不得让 HTTP 服务崩溃或退出。
- HTTP 服务停止/重启不得中断正在进行的本机截图或录屏（除非用户主动关闭模块）。
- 一个模块的窗口/面板崩溃不得影响另一个模块的核心服务。

## 3. 已确认的产品决策（2026-11-19）

1. **许可证**：接受 GPL-3.0。移植 macshot 代码后，整个项目按 GPL-3.0 分发；仓库保留 `LICENSE` 与来源说明。
2. **设置**：统一使用我们自己的 SwiftUI 设置窗口，不把 macshot 的独立设置 App 原样搬进来；按模块分区。
3. **首期范围**：只做“截图 + 录屏”。上传（Google Drive / imgbb / S3）、翻译、全局热键先不做；后续要做时仍归 `capture` 模块，且不得影响 `remote`。
4. **截图/录屏的使用场景**：Mac 本机使用，**不做手机端截图/录屏**。
5. **模块开关**：`remote` 与 `capture` 必须能独立开关；关闭一个不影响另一个。

## 4. 验收清单（每次改动后自查）

- [ ] 关闭 `remote` 后，截图/录屏仍可用。
- [ ] 关闭 `capture` 后，手机面板、配对、按钮、激活仍可用。
- [ ] 手机面板没有截图/录屏入口。
- [ ] `APIRouter` 里没有 capture 相关路由。
- [ ] `Capture` 代码里没有 `DeckState` / `ConfigStore` / `PairingManager` 引用。
- [ ] `RemoteControl` 代码里没有 `MacShotKit` / `CapturePreferences` 引用。
- [ ] 截图历史只写 `Capture/` 目录，设备/按钮只写 `RemoteControl/` 目录。
- [ ] 设置页按模块分区，没有跨模块选项混排。
- [ ] 新增文件在正确的模块目录下，没有放错到 `Core` 或另一个模块。

## 5. 当前落地状态（2026-11-19）

- 已加入 `LICENSE`（GPL-3.0）与 `THIRD_PARTY_NOTICES.md`。
- 已建立 `Sources/MacShotKit/`，引入 macshot 的 `ScreenCaptureManager.swift`，只由 `capture` 模块 import。
- 已落地 P0：
  - `Core/FeatureModule.swift`：模块契约
  - `Core/ModuleRegistry.swift`：模块开关、启停、按启用状态拼菜单
  - `Modules/RemoteControl/RemoteControlModule.swift`：包装原有 HTTP/配对/按钮服务
  - `Modules/Capture/CaptureModule.swift`：Mac 本机「全屏截图」菜单
  - 设置窗口改为侧边栏，新增「模块」页与「截图与录屏」页
- 已落地 P1：
  - 菜单栏「截图与录屏 → 全屏截图」
  - 保存 PNG / 复制剪贴板 / 权限检查 / 系统授权入口
  - 点击截图会触发系统「屏幕录制」授权页
- 下一步：P2 接入区域/窗口/多屏/延时/标注/历史；P3 接入录屏 MP4/GIF 与视频编辑。
- 详细记录：`Docs/archive/2026-11-19-module-shell-and-capture/SUMMARY.md`。

## 6. 当前落地状态（2026-11-20）

- 已完成 P2 截图链路：
  - 全屏 / 区域 / 窗口 / 滚动截图，截图延时、快速保存、快速 OCR。
  - 标注编辑器：矩形、实心矩形、椭圆、直线、箭头、画笔、荧光笔、文字、序号、马赛克、模糊、聚光灯、测量、裁剪。
  - 输出格式 PNG / JPEG / HEIC / WebP / AVIF，质量与目录可配置。
  - OCR（Vision）、钉图、最近截图历史。
- 已完成 P3 录屏链路：
  - 区域 / 全屏 / 窗口 MP4（H.264 + AAC 系统音频），15/30/60/120 fps。
  - 区域 GIF（5/10/15 fps）。
  - 顶部录制 HUD、菜单栏停止、完成 toast。
- 未移植的能力、原因与验证记录：`Docs/architecture/MACSHOT_PORT.md`。
- 边界仍然有效：`capture` 不注册 HTTP、不进入手机面板、不读写 `remote` 的配置/数据。

