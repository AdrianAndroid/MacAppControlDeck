# 技术设计：add-core-control-loop

## 总体架构

```
┌─────────────────── iPhone / iPad / Android ───────────────────┐
│  Safari / 主屏幕 Web App（静态单页 HTML/CSS/JS，由 Mac 提供）  │
│  localStorage: token、设备名                                   │
└─────────────▲─────────────── HTTP（局域网，明文）───────────────▲┘
              │ Bearer token + Host/Origin 校验                  │
┌─────────────┴──────────── Mac 端宿主程序（Swift） ──────────────┴┐
│  host-app-shell：MenuBarExtra 常驻 + 设置窗口                    │
│    ├─ lan-api：NWListener + NWProtocolHTTP（零三方依赖）         │
│    │    ├─ /api/pair         POST  配对（需一次性配对码）        │
│    │    ├─ /api/buttons      GET   已配置按钮（需凭证）          │
│    │    ├─ /api/activate     POST  激活按钮（需凭证）            │
│    │    ├─ /api/health       GET   无凭证健康检查（仅存活信号）  │
│    │    └─ /（静态面板、图标资源）                                │
│    ├─ pairing-auth：配对码 / token / 设备表（JSON）              │
│    ├─ button-panel-config：按钮配置（JSON，App Support 目录）    │
│    └─ app-control：NSWorkspace / NSRunningApplication           │
└───────────────────────────────────────────────────────────────────┘
```

## 选型与理由

### Mac 端：Swift + SwiftUI（菜单栏 + Dock 双驻留）

- 运行环境 macOS 15.6，可用 `MenuBarExtra`（macOS 13+）做常驻菜单 + 辅助设置窗口。
- **用户已确认采用"菜单栏 + Dock 双驻留"**：Dock 图标存在，便于手动选中退出；管理入口在菜单栏。
- 构建：`swift build -c release` + 脚本组装 .app，不做公证分发。
- **签名：稳定自签名证书**（`Build/setup-signing.sh` 一次性创建，`Build/build.sh` 自动使用）。
  原因：TCC（辅助功能授权）按"代码需求"绑定签名；ad-hoc 签名的 App 每次重新构建 cdhash 都会变，
  系统会保留旧条目但实际不信任，表现为"开关是开的、授权却不生效"。
  使用同一张自签名证书后，重新构建不再丢授权。未创建证书时回退 ad-hoc，并在构建输出中警告。
- 图标：`Build/AppIcon.icns`（`Build/make-icon.swift` 生成），`Info.plist` 声明 `CFBundleIconFile`。

### 1. 如何启动和激活指定应用（app-control）

**流程总览**

```
点击按钮
  ├─ 应用未运行 → openApplication 启动 → 等进程出现(≤15s) → 进入激活流水线
  └─ 应用已运行 → 激活流水线
      ① Dock 图标 AXPress（需辅助功能）   ← 首选，等价真人点击 Dock
      ② AXRaise 目标窗口（需辅助功能）     ← 应用不在 Dock 或 AXPress 未命中
      ③ NSRunningApplication.activate(from:) ← macOS 14+ 上下文激活
      ④ LSOpen（openApplication, activates=true）
      → 成功判定：目标应用成为前台即算成功
```

- **定位**：`NSWorkspace.shared.urlsForApplications(withBundleIdentifier:)` 按 Bundle ID 找应用；找到多个时选路径最优者（优先 `/Applications`）。显示名与路径仅作展示与备份判断，**不**用于定位。
- **启动（未运行）**：`NSWorkspace.openApplication(at:configuration:)`（`activates = true`），轮询进程出现（最长 15s），随后进入激活流水线拿焦点。**不以“窗口出现”作为启动成功条件**（原因见第 2 节：进程内窗口列表不可靠）。
- **首选激活：Dock 图标 AXPress（辅助功能）**。通过 `AXUIElementCreateApplication(Dock进程)` 找到 Dock 的应用图标项，`AXUIElementPerformAction(kAXPressAction)`。
  由 Dock 进程执行激活，与真人点击 Dock 完全等价：系统按调度中心规则切到窗口所在空间并把应用置前；**连 JetBrains 类应用的“卡死态”也能一次点开**（实测 DevEco 生效，0.06s 返回）。
  匹配规则：Dock 项标题与应用显示名/`CFBundleName`/URL 文件名做归一化（小写、去非字母数字）后相等或前缀包含。
- **次选：AXRaise（辅助功能）**。遍历目标应用 `kAXWindowsAttribute`，过滤 >100×100 的普通窗口，取消 `kAXMinimized` 后执行 `kAXRaiseAction`。适用于不在 Dock 的应用；JetBrains 应用在“卡死态”下 AX 树为空时此路不通。
- **兜底：`activate(from:)` / LSOpen**。均为公开 API；后台进程调用时可能只标记前台不切空间（见第 2 节），仅在前面策略不可用时使用。
- **成功判定：目标应用成为前台（`frontmostApplication`）**。窗口可见性**不**作为成功门槛，只写入日志用于诊断。依据：Deck 进程内 `CGWindowListCopyWindowInfo` 与同机其他进程对同一时刻的可见性判断互相矛盾（见实测记录），以其为门槛会产生“成功却报失败”。
- **最小化窗口**：Dock AXPress 走系统行为（与真人点击一致）；AXRaise 路径会显式取消最小化。
- **无可见窗口的应用**（菜单栏/后台类）：激活照常执行，按 `activationPolicy` 如实反馈，不模拟 Cmd+N。
- **多窗口**：交由系统选择主窗口，不做逐窗口精细选择。

### 2. 如何处理桌面空间（Space）——真机实测结论

**前置系统开关（必须开启）**

> 系统设置 → 桌面与程序坞 → 调度中心 →「切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间」

本项目调试期间该开关实际处于**关闭**状态：所有激活请求只切菜单栏、不切桌面，看起来像程序故障。该开关在系统 UI 中不显眼（藏在调度中心页底部 Tips 附近），用户需搜索"空间"才能找到。本程序不修改该设置，但需在文档与故障排查中显式说明，并提供判断方法：**手动点 Dock 图标也不跳桌面 → 即该开关问题**。

**后台进程激活的系统限制（实测）**

手机触发时 Deck 是后台进程，没有用户交互上下文。对已运行的应用：

- `NSRunningApplication.activate(options:)` / `activate(from:)` / LSOpen 可能只把目标标记为前台，**不触发空间切换**；
- 目标应用（尤其 JetBrains/Java 类）随后会进入“卡死态”：`frontmostApplication` 已是目标、窗口仍在其他空间、菜单栏已切换但桌面上看不到窗口；此后所有常规激活 API 均变为无效空操作；
- 卡死态下 JetBrains 应用的 AX 树会变空（`kAXWindowsAttribute` 返回 0 个窗口），AXRaise 同样无效；**新建窗口/冷启动实例则 AX 正常**；
- 已验证无效的路径：legacy `.activateIgnoringOtherApps`、自激活后真实交接、AppleScript `activate`/`reopen`、合成 Cmd+Tab 键（系统忽略注入事件）、`AXUIElementCreateWindow`（私有 API，公开 SDK 不存在）。

**因此**：跨空间切换的可靠路径是 **Dock 图标 AXPress**（Dock 进程代为激活，系统规则原生生效）。该方案不需要私有 API、不需要关闭 SIP，仅需一次辅助功能授权。

### 3. 权限需求清单（按需，不锁定全量）

| 权限 | 何时需要 | 在哪设置 | 说明 |
| --- | --- | --- | --- |
| 本地服务监听 | 程序启动即是服务端 | 无需系统开关 | 纯监听不弹窗 |
| 辅助功能 | **强烈建议**：跨空间切换、最小化还原、卡死态恢复 | 系统设置 → 隐私与安全性 → 辅助功能 | 核心路径（Dock AXPress / AXRaise）。未授权时只能走公开激活 API，对“窗口在其他空间”的应用可能只标记前台。UI 有状态灯（2s 轮询）与一键跳转授权按钮 |
| 自动化（Apple Events） | 不使用 | — | AppleScript 后备方案已被实测淘汰，不请求 |
| 屏幕录制 | 不使用 | — | 窗口标题/可见性仅作日志诊断，不作为判定依据，也不请求 |
| 开机自启 | 默认关闭 | `SMAppService` | 不偷偷写入 LaunchAgents |

**TCC 授权与签名的关系（踩坑）**：辅助功能授权按“代码需求”绑定签名。ad-hoc 签名下每次重新构建/替换 App，系统会保留旧条目但实际不信任（开关开着、`AXIsProcessTrusted()` 仍为 false）。解决：用稳定自签名证书签名；授权记录一旦建立，重建不再失效。修复手段：删除该条目后重新添加 `/Applications/MacAppControlDeck.app`，再重启程序（仅切换开关不会重写记录）。

### 3.1 实测记录（决策依据）

| 方案 | 结果 | 结论 |
| --- | --- | --- |
| Dock 图标 AXPress（辅助功能） | 成功：front=目标、空间切换，卡死态也可恢复；0.06s 返回 | **首选** |
| AXRaise 目标窗口（辅助功能） | AX 树可读时成功（实测 0→1 可见）；JetBrains 卡死态 AX 树为空时失败 | 次选 |
| `activate(from:)` / LSOpen / legacy activate | 后台进程调用时只标记前台、不切空间 | 仅兜底 |
| 自激活 + 真实交接、AppleScript activate/reopen | 对卡死态均无效 | 淘汰 |
| 合成 Cmd+Tab（CGEvent） | 系统忽略注入事件 | 淘汰 |
| `AXUIElementCreateWindow` | 公开 SDK 不存在（私有 API） | 不可用 |
| 延长窗口等待（5s→12s→30s+） | 无改善；切换耗时不可控且判定窗口不可靠 | 不依赖窗口判定 |
| 进程内 CGWindowList 作为判定依据 | 外部进程同一秒看到可见=1，Deck 内持续 0 达 11s+ | **不作门槛，只记日志** |
| 自动温和重启卡死应用 | 可行但打断工作（IDE 弹未保存对话框） | 已移除，改为不杀 App |

### 4. 手机如何发现并连接 Mac（lan-api）

- Mac 端菜单栏窗口直接展示：`http://<局域网IPv4>:<端口>/panel/` + 二维码（CoreImage `CIQRCodeGenerator`）。
- 不做 mDNS 引导手机自动发现（iOS 网页无法做 mDNS），也不做互联网远程访问。
- IP 变化的影响：token 存在 Web App 的 localStorage 中，按 origin 隔离。Mac IP 变化产生新 origin，旧 token 不在新 origin —— 用户重新扫码打开新地址，若 token 失效则引导重新配对（配对码再次展示）。此为已知取舍，写入文档。

### 5. 如何配对并防止任意命令执行（pairing-auth）

- **配对流程**：
  1. Mac 端菜单栏窗口生成 6 位一次性配对码，TTL 2 分钟，用后即焚；错误输入累计 3 次即作废，防爆破。
  2. 手机 POST `/api/pair`（附配对码 + 设备名）→ 服务端签发随机 256-bit token（`SecRandomCopyBytes`），服务端把 token（连同设备名、配对时间）存入本地 `devices.json`，手机 token 存 localStorage。
  3. 之后所有请求带 `Authorization: Bearer <token>`（或自定义头 `X-Device-Token`，避免純基保头被代理剥离的疑虑——**用自定义头**，非 SNI 代理剥离问题实测不同的代理行为不同，选自定义头更稳）。
- **撤销**：Mac 端设备管理列表可删除任一设备，删除后立刻拒绝其旧 token（服务端本地查询，内存与 JSON 同步更新）。
- **防任意执行**：
  - 服务端**只有**上表 4 个端点 + 静态资源；`/api/activate` 只接受"按钮 ID"，不接受应用路径、bundle id、命令字符串。按钮 → 应用的映射完全由 Mac 端配置决定。
  - 请求体大小上限（如 4KB）、Content-Type 白名单（`application/json`）。
- **跨站/DNS 重绑定防护**：
  - 所有端点**必须**带 token 自定义头 → 浏览器跨站发起需通过 CORS 预检，服务端对 OPTIONS/Preflight 一律拒绝，普通 POST/GET 无自定义头一律 401。
  - 校验 `Host` 头必须是本机局域网 IP/localhost；`Origin` 若存在则必须与面板地址一致。
  - 凭证**不**写入 URL 查询参数、二维码或访问日志（日志只记时间/端点/成败，不记 token/配对码）。
- **明文 HTTP 的边界（如实声明）**：同一 Wi-Fi 网段的设备理论上可嗅探得到 token 与配对码。第一版接受该风险（家庭可信网络场景），用"短时配对码 + 可撤销 token"减小危害半径；若用户要求，可在第二阶段评估 HTTPS（自签证书 + 信任引导）。

### 6. iOS Safari 的实际限制（remote-web-panel 设计前提）

- **无后台常驻**：网页切后台/锁屏后不保证长连接，回来时必须重新探测 `/api/health` 再展示连接状态，不假装在线。
- **无 mDNS/自动发现**：只能靠用户扫码或手动输入 URL。
- **localStorage 在主屏幕 Web App 与 Safari 是独立存储**；主屏幕 App 与 Safari 各自配对一次即可。
- **添加到主屏幕**支持：`apple-mobile-web-app-capable`、`apple-touch-icon`、`viewport-fit=cover`、`theme-color`,使 Web App 以独立窗口全屏运行（macOS/iPad 亦可用）。
- **兼容 iPad / Android**：自适应布局（CSS Grid + `env(safe-area-inset-*)`），原生 Fetch + token 头在 Android Chrome 同样可行。

## 持久化（button-panel-config / pairing-auth）

- 目录：`~/Library/Application Support/MacAppControlDeck/`
  - `buttons.json` —— 按钮数组：id（UUID）、显示名、Bundle ID、应用路径缓存、图标缓存文件名、排序号
  - `devices.json` —— 已配对设备：token（明文存本机，与系统钥匙串权衡：MVP 用文件 + `chmod 0600`，后续可迁 Keychain）、设备名、配对时间
  - `settings.json` —— 端口、面板设置
- 写入策略：原子写（临时文件 + rename），防半写损坏。

## 风险与未验证行为

- `CGWindowListCopyWindowInfo` 在本进程内的数据与同机其他进程不一致（系统缓存行为，未找到官方解释），本项目已不依赖它做判定；如后续需要窗口级能力，需改用 AX 或截图方案。
- Dock AXPress 依赖应用在 Dock 中可见；无 Dock 图标的应用（纯菜单栏）会落到 AXRaise/公开 API 路径，跨空间能力受限。
- 卡死态与 JetBrains 应用的 AX 树清空属应用自身/系统行为；本项目通过 Dock 点击绕过，不尝试修复应用。
- 全屏空间与多显示器场景未穷尽验证，仍以系统调度中心规则为准。
- `NWProtocolHTTP` 服务在慢客户端/异常断开场景的健壮性需要测试用例覆盖。
