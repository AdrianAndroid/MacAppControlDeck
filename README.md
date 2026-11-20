# MacAppControlDeck · Mac 应用快捷控制台

在局域网内用 iPhone / iPad / Android 的浏览器遥控 Mac：点击按钮即可启动或激活对应应用，自动切换到应用窗口所在的虚拟桌面并置于前台。无云服务、无公网、无注册账号。

同时按“功能模块”组织：电脑遥控与截图/录屏是两个独立模块，各自拥有服务、数据、权限和生命周期。截图/录屏在 Mac 本机使用，不经过手机。

需求与设计见 `openspec/`（OpenSpec 管理，变更 `add-core-control-loop`）。

---

## 功能

- **一键启动 / 切换应用**：手机点按钮 → 应用启动或切到前台；窗口在其他「桌面空间」时自动跳过去
- **跨桌面切换**：通过「按下 Dock 图标」实现，与真人点击 Dock 完全等价，复用系统调度中心的跨空间规则
- **按钮管理**：Mac 端搜索添加应用（按 Bundle ID 绑定）、重命名、排序、删除（有确认）
- **配对与撤销**：6 位一次性配对码（2 分钟、错 3 次作废），已配对设备可随时撤销
- **菜单栏常驻**：应用只占菜单栏，不占 Dock；下拉菜单直接点应用 / 快捷操作 / 命令
- **截图与录屏（Mac 本机模块）**：全屏 / 区域 / 窗口 / 滚动截图，截图延时、快速保存、快速 OCR；标注编辑器（矩形、椭圆、直线、箭头、画笔、荧光笔、文字、序号、马赛克、模糊、聚光灯、测量、裁剪）；OCR、钉图、最近截图历史；PNG/JPEG/HEIC/WebP/AVIF 输出
- **录屏（Mac 本机模块）**：区域 / 全屏 / 窗口 MP4（H.264 + 系统音频，真实帧时序），15/30/60/120 fps；区域 GIF（5/10/15 fps）；3-2-1 倒计时；顶部录制 HUD 与录制边框；磁盘不足/休眠自动停止
- **视频剪辑**：多段剪切、0.5–4× 变速、字幕（可指定起止时间）、分轨音量、MP4 导出进度/取消、直接导出 GIF
- **模块开关**：设置 →「模块」可独立启用/关闭电脑遥控与截图录屏，关闭一个不影响另一个
- **保存体验**：系统快门音、`{date}/{time}/{app}` 文件名模板（可分子文件夹）、保存后右下角悬浮缩略图（点击再编辑 / 拖出为文件）、缩略图网格截图历史
- **手机端面板**：静态单页 Web，可「添加到主屏幕」当 App 用；明文局域网 HTTP

## 环境要求

- macOS 14+（构建工具链 Swift 5.9+）
- 手机与 Mac 在同一局域网

## 下载安装

从 [Releases](https://github.com/AdrianAndroid/MacAppControlDeck/releases) 下载对应芯片的安装包：

| 芯片 | 资产 |
| --- | --- |
| Apple Silicon（M 系列） | `MacAppControlDeck-<版本>-arm64.dmg` |
| Intel | `MacAppControlDeck-<版本>-x86_64.dmg` |

终端执行 `uname -m` 可确认芯片（`arm64` / `x86_64`）。发布包为 ad-hoc 签名、未公证，首次打开需右键「打开」或在「隐私与安全性」中允许。

## 构建与安装

```zsh
./Build/setup-signing.sh   # 可选：创建稳定自签名证书（无 Apple 开发证书时建议执行一次）
./Build/build.sh           # swift build -c release + 组装 .app + 签名 + 图标
open BuildOutput/MacAppControlDeck.app
```

安装到「应用程序」目录：

```zsh
cp -R BuildOutput/MacAppControlDeck.app /Applications/
open /Applications/MacAppControlDeck.app
```

生成双架构发布包（DMG + ZIP + 校验和）：

```zsh
./Build/package-release.sh arm64
./Build/package-release.sh x86_64
```

> **为什么需要稳定证书**：辅助功能授权（TCC）按签名绑定。ad-hoc 签名每次重新构建都会变，系统会保留旧授权条目但实际不信任（表现为「开关是开的、授权却不生效」）。用固定证书（Apple Development 或自签名）后，重新构建不再需要重新授权。

运行后：菜单栏出现滑块图标，Dock 也有图标。App 自动在本机局域网 IP 上监听（默认端口 47615，被占用自动 +1），窗口首屏显示面板地址（形如 `http://192.168.x.x:47615/panel/`），可点击复制。

## 首次配置（按顺序）

### 1. 授予「辅助功能」权限（强烈建议）

系统设置 → 隐私与安全性 → 辅助功能 → 点 `+` 添加 `/Applications/MacAppControlDeck.app`，确认开关为开，**然后重启本程序**。

- 授权后：跨桌面切换走「Dock 图标点击」，最可靠（JetBrains 类应用的卡死态也能一次点开）
- 未授权：只能使用常规激活 API，对「窗口在其他桌面空间」的应用可能只标记前台、不跳桌面
- App 窗口内有状态灯（2 秒轮询）：绿色=已授权，橙色=未授权，附「去授权」按钮一键跳转

### 2. 打开调度中心开关（必须）

> 系统设置 → 桌面与程序坞 → 调度中心（Mission Control）→
> **「切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间」**

- 它不一定默认开启（本机调试期间就是关的），且位置不显眼，建议直接搜索「空间」
- 开关关闭时：点按钮只切菜单栏、不跳桌面，看起来像程序故障
- 判断方法：**手动点 Dock 图标也不跳桌面 → 就是这个开关的问题**
- 本程序不修改该设置

## Mac 端使用（菜单栏）

1. 启动后应用只出现在菜单栏（`slider.horizontal.3` 图标），没有 Dock 图标，也不开主窗口
2. 点菜单栏图标打开下拉菜单：
   - 顶部显示当前面板地址，可直接「在浏览器打开面板」或「复制面板地址」
   - 「应用」「快捷操作」子菜单就是已配置的功能按钮，点一下立即执行（应用带真实图标）
   - 「截图与录屏」子菜单：全屏 / 区域 / 窗口 / 滚动截图；快速保存、快速 OCR；录制 MP4 / GIF；截图延时；最近截图；输出到 `~/Pictures/MacAppControlDeck` 与 `~/Movies/MacAppControlDeck`
   - 「配对手机…」生成 6 位配对码并打开设置
   - 「设置…」进入首选项（⌘,），「退出」结束服务（⌘Q）
3. 关闭设置窗口不会退出服务；菜单栏图标常驻，服务继续监听端口

## 手机端使用

1. 手机与 Mac 连接同一 Wi-Fi
2. Safari 打开 Mac 端显示的面板地址
3. 点击 Mac 菜单栏「配对手机…」（或设置 → 通用 → 生成 6 位配对码），在手机输入 → 配对成功，显示按钮列表
4. （可选）Safari 分享 → 添加到主屏幕，之后像 App 一样全屏使用

点击按钮后的状态行会如实显示结果（`已切换到前台` / `已启动并切到前台` / 具体失败原因）。

## 添加 / 管理按钮（Mac 端）

菜单栏 →「设置…」→「按钮」标签页：

- 「添加按钮」→「添加应用按钮…」搜索选择应用（按 Bundle ID 绑定）；也可添加「快捷操作」或「命令按钮」
- 每行支持「⋯ → 重命名…」、↑↓ 排序、「⋯ → 删除…」（删除有确认）
- 应用被删除/移动后按钮显示「应用缺失」，可回到 App 列表重新绑定
- 「设备」标签页可撤销任意设备的配对（撤销后旧凭证立即失效）

## 激活策略（简述）

点击按钮后的执行顺序：

1. **应用未运行** → `openApplication` 启动 → 等进程出现 → 进入激活流水线
2. **已运行** → 按优先级尝试：
   - **Dock 图标 AXPress**（辅助功能）：由 Dock 进程执行激活，等价真人点击，跨空间原生生效
   - **AXRaise 目标窗口**：应用不在 Dock 时使用，会顺带取消最小化
   - **`activate(from:)` / LSOpen**：公开 API 兜底
3. **成功判定**：目标应用是否成为前台应用。窗口可见性只记诊断日志——进程内 `CGWindowList` 数据在真机上与其他进程不一致，不可作为判定依据

详细原理、实测记录与取舍见 `openspec/changes/add-core-control-loop/design.md`。

## 安全边界（务必阅读）

- 手机只能执行白名单动作：列出按钮、激活某个已配置按钮；**不能**执行任意 shell / 任意应用
- 所有接口要求配对换发的随机 token（配对码 2 分钟有效、错 3 次作废）
- 通信为**明文 HTTP**：同网段设备理论上可嗅探到 token/配对码，请仅在可信家庭局域网使用；HTTPS 为后续评估项
- 程序不修改系统设置、不默认开机自启；电脑遥控使用可选的辅助功能授权，截图/录屏使用屏幕录制授权（仅在使用 capture 模块时申请），两者互不影响
- 数据存放在 `~/Library/Application Support/MacAppControlDeck/`（`buttons.json` / `devices.json` / `icons/`），程序重启后保留

## 快捷操作与命令按钮

「快捷操作」分组支持两类按钮：

- **按键组合**：预设（桌面左/右、⌘C、⌘V、⌘A、⌘Z、回车、Esc、F1–F12）或自定义录制/拼凑。适用于普通应用（编辑、IDE 等）。
- **命令按钮**：执行某个应用内置的命令行（例如 Snipaste 的 `snip`），参数只在 Mac 端配置，手机端仍只发送按钮 ID。

> **已知限制**：Snipaste 等注册系统级热键的应用会忽略注入的按键（F1 对其无效，已实测输入监控授权也不能解决），因此这类应用请用**命令按钮**方式触发（例：应用选 Snipaste、参数 `snip`）。

**连续点击**：每个按钮有独立队列（上限 8 条），点击立即入队、按顺序执行、不阻塞后续点击；系统会按操作类型设置超时（快捷操作 2.5s、命令 4s、应用 20s），超时的命令自动放弃并继续执行队列，无需等待提示消失。

## 测试

```zsh
swift test     # 40 项，含真实 TCP 服务器与真实应用激活的端到端用例
```

## 已知限制

- 最小化窗口的恢复由系统/应用决定；无法确认时如实反馈，不谎报
- 无可见窗口的应用（菜单栏类）激活后不新建窗口（依应用自身行为）
- 没有 Dock 图标的应用无法使用 Dock 点击路径，跨空间能力受限
- iOS 主屏幕 Web App 与 Safari 的 localStorage 互相独立，两端需分别配对一次
- Mac IP 变化后需重新扫码打开新地址（可能需重新配对）
- Mac 休眠/锁屏/退出后不可用，手机会显示「Mac 未连接」（属设计行为）
- 滚动截图是自动向下滚动 + 重叠拼接；如果选区包含固定侧栏/固定工具栏，长图里会重复出现这些固定区域，建议只框选可滚动内容
- 上传（Google Drive / imgbb / S3）、翻译、Sparkle 自动更新、账号体系不移植；详细对照见 [Docs/architecture/MACSHOT_PORT.md](Docs/architecture/MACSHOT_PORT.md)

## 故障排查

| 现象 | 处理 |
| --- | --- |
| 手机显示「Mac 未连接」 | 确认 Wi-Fi 同网段、Mac 端 App 正在运行；Mac 休眠会断开 |
| 面板要求重新配对 | 凭证失效或被撤销，在 Mac 端重新生成配对码 |
| 按钮显示「应用缺失」 | 应用已卸载/移动，在 Mac 端重新绑定 |
| 端口冲突 | 服务自动尝试 47615–47634，以窗口显示地址为准 |
| 点击无反应 | 看按钮下状态行：失败原因会原样显示（如「启动失败：…」） |
| 面板地址是 169.254.x.x、手机访问不到 | 该地址属于未联网的网卡（常见于有线口 en0 没插网线、Wi-Fi 实际是 en1）。本版已改为「可路由地址优先」，若仍显示 169.254 请检查网络连接 |
| Android Chrome 一直转圈/提示无法连接 | 浏览器把 `http://` 强制升级成 HTTPS，而服务只支持明文 HTTP。完整输入 `http://IP:端口/panel/`，关闭 Chrome「始终使用安全连接」（或 `chrome://flags/#https-upgrades` 设为 Disabled），也可改用 Firefox |
| 配对提示成功但仍停在配对页 | 旧版在「按钮数为 0」时会退回配对页；本版已修复为进入主界面并显示空状态，按提示在 Mac 端添加按钮即可（面板 5 秒自动刷新） |
| 点击后只切菜单栏、不跳桌面 | ①检查调度中心开关（见上）；②检查辅助功能状态灯是否绿色。手动点 Dock 图标也不跳桌面即为开关问题 |
| 辅助功能状态灯一直橙色 | TCC 记录绑定了旧签名：删除该条目，重新添加 `/Applications/MacAppControlDeck.app`，再重启程序 |
| 已授权屏幕录制却仍提示授权 | ad-hoc 签名每次构建都会变，系统会保留旧条目而 `CGPreflightScreenCaptureAccess` 误报未授权。本版会先用真实窗口抓取探针确认，能抓到画面就不再弹窗；若仍提示，删除系统设置里的旧条目重新添加，或执行 `Build/setup-signing.sh` 固定证书后授权一次 |
| F1 触发不了 Snipaste 等全局热键应用 | 已知限制：请改用「命令按钮」（应用选 Snipaste、参数 `snip`）。普通应用中 F1 可正常注入 |
| 点击启动台/系统界面后显示"未确认" | 启动台等系统界面不会以常规应用注册进程，属正常；已打开即可用 |
| 快捷键提示"当前处于安全输入状态" | 密码框/锁屏等安全输入场景会屏蔽按键注入，退出安全输入后重试 |
| 桌面左/右切换无反应 | 检查「自动化」权限：系统设置 → 隐私与安全性 → 自动化 → 勾选 MacAppControlDeck → System Events；并确认系统键盘快捷键「向左/向右切换桌面」为默认的 ⌃←/⌃→ |
| 重新构建后授权失效 | 确认 `build.sh` 输出了「已使用签名身份：…」而不是「ad-hoc 签名」；必要时执行 `setup-signing.sh` 并在钥匙串中信任该证书 |

运行日志：`~/Library/Application Support/MacAppControlDeck/logs/activation.log`（含每条激活策略的执行结果）。

## 项目结构

```
Sources/MacAppControlDeck/
├── App/DeckApp.swift            # 入口：菜单栏应用（无主窗口）
├── App/DeckState.swift          # remote 模块运行状态（服务/权限/配对/按钮/设备）
├── Core/                        # 模块协议、注册表、菜单/设置壳（不放业务逻辑）
├── Modules/
│   ├── RemoteControl/           # 电脑遥控模块：HTTP 服务/配对/手机面板/按钮
│   └── Capture/                 # 截图与录屏模块：Mac 本机使用，不接 HTTP
├── Control/AppControl.swift     # 激活流水线（Dock AXPress / AXRaise / 兜底）
├── Control/QuickActionRunner.swift # 菜单栏按钮执行器（与 HTTP 接口同源）
├── Server/                      # remote 模块：NWListener HTTP 服务、路由
├── Store/                       # remote 模块：配置持久化、配对管理
├── UI/MenuBarController.swift   # NSStatusItem + NSMenu（按模块拼接菜单）
├── UI/SettingsView.swift        # 统一设置壳：按模块分区
├── UI/ButtonsSettingsView.swift # remote 模块：按钮管理
└── Panel/PanelHTML.swift        # remote 模块：手机端单页 Web 面板
Sources/MacShotKit/              # macshot 上游功能代码，只允许 capture 模块 import
Build/
├── build.sh                     # 构建/签名/打包（含图标），产出到 BuildOutput/
├── package-release.sh           # 按 arm64 / x86_64 生成可分发 DMG + ZIP
├── setup-signing.sh             # 一次性创建稳定自签名证书
├── make-icon.swift              # 生成 AppIcon.iconset
└── Info.plist                   # Bundle 元数据（含 Automation 用途说明）
BuildOutput/                     # 构建产物（.gitignore）
Docs/architecture/MODULES.md     # 【强制】模块边界与隔离规则
Docs/architecture/UPSTREAM_PORTING.md # 上游开源集成方法、验收标准与踩坑记录
Docs/archive/                    # 历史归档
```

> 模块边界是硬约束：`remote` 与 `capture` 各自拥有服务、数据、权限和生命周期，互不引用、互不混排。详见 [Docs/architecture/MODULES.md](Docs/architecture/MODULES.md)。

## 归档

- 2026-11-19 MVP 0.1.0：[Docs/archive/2026-11-19-mvp-0.1.0/SUMMARY.md](Docs/archive/2026-11-19-mvp-0.1.0/SUMMARY.md)
- 2026-11-19 远程快捷操作（快捷键 / 命令按钮 / 桌面切换）经验总结：[Docs/archive/2026-11-19-remote-quick-actions/SUMMARY.md](Docs/archive/2026-11-19-remote-quick-actions/SUMMARY.md)
- 2026-11-19 构建补齐、局域网地址与面板配对修复：[Docs/archive/2026-11-19-build-network-panel-fixes/SUMMARY.md](Docs/archive/2026-11-19-build-network-panel-fixes/SUMMARY.md)
- 2026-11-19 菜单栏常驻 + 首选项结构重构：[Docs/archive/2026-11-19-menubar-restructure/SUMMARY.md](Docs/archive/2026-11-19-menubar-restructure/SUMMARY.md)
- 2026-11-19 模块骨架与本机全屏截图（P0 + P1）：[Docs/archive/2026-11-19-module-shell-and-capture/SUMMARY.md](Docs/archive/2026-11-19-module-shell-and-capture/SUMMARY.md)
- 2026-11-20 macshot 截图/录屏能力移植：[Docs/archive/2026-11-20-macshot-port/SUMMARY.md](Docs/archive/2026-11-20-macshot-port/SUMMARY.md)
- 上游集成方法论（复用开源实现的正确方式）：[Docs/architecture/UPSTREAM_PORTING.md](Docs/architecture/UPSTREAM_PORTING.md)
- 2026-11-20 截图覆盖层与 macshot 体验对齐（工具条搬运/Retina/权限/热键/钉图 Esc）：[Docs/archive/2026-11-20-capture-parity-and-experience/SUMMARY.md](Docs/archive/2026-11-20-capture-parity-and-experience/SUMMARY.md)
- 2026-11-20 录屏/GIF 录制覆盖层与编辑流程对齐：[Docs/archive/2026-11-20-recording-overlay-parity/SUMMARY.md](Docs/archive/2026-11-20-recording-overlay-parity/SUMMARY.md)
