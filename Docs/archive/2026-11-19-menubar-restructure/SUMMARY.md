# 菜单栏常驻 + 首选项结构重构

日期：2026-11-19
提交前状态：工作区改动，未提交（本轮只做结构改造与验证）

## 背景与目标

参考 macshot 的形态：应用常驻菜单栏，功能入口在下拉菜单里，所有配置集中在「设置」窗口。
原来的实现是一个 SwiftUI `WindowGroup` 主窗口 + 极简 `MenuBarExtra`，主窗口兼任控制台和配置界面，Dock 里也有图标，不像一个常驻工具。

本轮目标：

1. 去掉主窗口与 Dock 图标，改为 `LSUIElement` 菜单栏应用
2. 下拉菜单直接放功能按钮（应用 / 快捷操作 / 命令），点击即执行
3. 服务状态、权限、配对、按钮管理、设备、关于全部收进设置窗口的四个标签页
4. 保持手机端 HTTP 面板与原有控制逻辑不变

## 结构变化

| 模块 | 变化 |
|---|---|
| `App/DeckApp.swift` | 移除 `WindowGroup` 与 `MenuContent`；`AppDelegate` 设置 `.accessory`；启动时安装菜单栏 |
| `App/DeckState.swift` | 从 `MainWindowView.swift` 抽出的唯一状态源；新增 `panelAddressText`、`copyPanelURL`、`openPanelInBrowser`、`perform(_:)`、`icon(for:)`、`isInstalled`、`restart`、`requestedSettingsTab` |
| `UI/MenuBarController.swift` | 新增：`NSStatusItem` + `NSMenu`，菜单每次打开时重建；应用子菜单显示真实 App 图标，快捷操作带组合键文字 |
| `Control/QuickActionRunner.swift` | 新增：菜单栏执行器，和 HTTP `/api/activate` 共用底层能力，独立串行队列保证连续点击顺序 |
| `UI/SettingsView.swift` | 新增：通用 / 按钮 / 设备 / 关于四个标签页；通用页含服务、权限、配对、登录启动 |
| `UI/ButtonsSettingsView.swift` | 从 `MainWindowView.swift` 迁入按钮管理、添加应用/快捷操作/命令的 sheet、重命名与删除确认 |
| `UI/MainWindowView.swift` | 删除（内容拆分到上述文件） |
| `Build/Info.plist` | 新增 `LSUIElement=true`，启动瞬间也不出现 Dock 图标 |

菜单结构（从上到下）：

```
面板：192.168.18.159:47615（不可点，显示当前地址）
在浏览器打开面板 / 复制面板地址
────
应用 ▸ 豆包 / Firefox / Chrome / Clash Verge（带真实图标）
快捷操作 ▸ 每个快捷键（标题后附 ⌘⇧4 形式）
────
配对手机…（生成配对码并打开设置-通用）
重启服务 / 启动服务
设置…（⌘,）
────
退出（⌘Q）
```

## 过程中踩的坑与修复

1. **SwiftUI `MenuBarExtra` 的菜单项不渲染图片**
   - 初版用 `MenuBarExtra` + `Label(icon: Image(nsImage:))`，菜单里只有文字，应用子菜单没有图标。
   - 改为原生 `NSStatusItem + NSMenu` 后，`NSMenuItem.image` 正常显示 App 图标与 SF Symbol。
2. **自定义设置窗口的标签页切换**
   - 设置窗口由 `NSHostingController(rootView: SettingsView())` 托管；`SettingsTab` + `DeckState.requestedSettingsTab` 让「配对手机…」总能定位到「通用」页。
3. **配对倒计时不刷新**
   - 原 `Timer.scheduledTimer` 在菜单/窗口交互期间会停；改为 `Timer` + `RunLoop.main.add(_, forMode: .common)`，并在生成时同步刷新一次文本。
   - 同时修正过期逻辑：到点立即清掉配对码并 `pairing.invalidate()`，不再显示已失效的码。
4. **应用图标显示为灰块**
   - `NSImage(contentsOfFile:)` 无法读取 `.app` 目录；改用 `NSWorkspace.shared.icon(forFile:)`。
5. **菜单动作与手机端行为一致性**
   - 菜单执行复用同一份 `ButtonConfig`，应用/快捷键/命令三类走同一套底层实现；失败时弹 `NSAlert` 说明原因，不静默失败。

## 验证

- `swift build` 通过；`swift test` 36 个测试全部通过
- 安装到 `/Applications/MacAppControlDeck.app`，`lsappinfo` 显示 `ApplicationType=UIElement`（无 Dock 图标）
- 状态栏菜单可打开，条目齐全；应用子菜单显示 4 个应用及真实图标
- 「复制面板地址」后 `pbpaste` 得到 `http://192.168.18.159:47615/panel/`
- 「配对手机…」打开设置并定位到「通用」，配对码显示且倒计时正常（`剩余 1:56`）
- `/api/health` 返回 `{"app":"MacAppControlDeck","ok":true,"version":"0.1.0"}`

## 遗留

- 设置窗口为自定义 `NSWindow`，标签样式是系统默认的分段式，不是系统「设置」的工具栏图标样式；功能不受影响。
- 登录时自动启动使用 `SMAppService`，需要应用在 `/Applications` 且有稳定签名；自签名环境下注册可能被系统拒绝，界面会回显错误。
- 尚未提交 git；本轮未改动 HTTP 协议与手机面板。
