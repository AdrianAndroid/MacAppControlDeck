# MacAppControlDeck · MVP 0.1.0 阶段总结（归档于 2026-11-19）

## 一、项目定位

把闲置 iPhone（或 iPad / Android）变成 Mac 应用快捷控制台：同一局域网内，手机浏览器打开面板，点击按钮即可在 Mac 上启动或激活对应应用，并尽可能切换到该应用所在桌面空间。

- 项目目录：`/Users/zhaojian/Desktop/MacAppControlDeck`（独立项目，与 ClearCallKeyBridge 无关）
- OpenSpec 变更：`openspec/changes/add-core-control-loop`（仍为活动变更，含第一/第二阶段任务）
- 版本：0.1.0（MVP，第一阶段闭环已打通）

## 二、技术选型落点

| 层 | 实现 |
| --- | --- |
| Mac 宿主 | Swift + SwiftUI，菜单栏（MenuBarExtra）+ Dock 双驻留，窗口单列卡片布局 |
| HTTP 服务 | Network.framework `NWListener` 自建 HTTP/1.1 解析（零三方依赖）。原因：macOS 26 SDK 已移除 `NWProtocolHTTP` 公开 Swift 接口 |
| 应用控制 | `NSWorkspace.urlsForApplications(withBundleIdentifier:)` 定位；未运行 `openApplication`，已运行 `NSRunningApplication.activate` |
| 手机端 | Mac 托管的单页 HTML/CSS/JS（无框架、无构建），localStorage 存 token |
| 持久化 | `~/Library/Application Support/MacAppControlDeck/` 下 JSON（buttons/devices）+ 图标 PNG 缓存，原子写、0600 权限 |
| 打包 | `Build/build.sh`：`swift build -c release` + 组装 .app + ad-hoc 签名 |

## 三、已实现功能

### 已自动验证（24/24 测试通过）

- 服务启动与端口回退（47615–47634）、健康检查
- 配对码：6 位、2 分钟 TTL、错误 3 次作废、用后即焚、频率限制
- 凭证：256-bit 随机 token、Bearer / X-Device-Token 鉴权、撤销后即时 401
- 端点白名单：`GET /api/health`、`POST /api/pair`、`GET /api/buttons`、`POST /api/activate`
- 未知按钮 ID → 404 且不启动任何应用；超大请求体 413；非法请求 400/415；伪造 Host 403
- 真实激活链路（计算器实测）：未运行 → `launched` 且成为前台；已运行 → `activated`（不误报 launched）
- 跨重启持久化（按钮、顺序、名称、设备表）
- 真实 TCP 服务器端到端用例（URLSession → 服务端 → 路由 → 响应）

### 界面（已截图核对）

- 服务状态卡：运行状态、端口、完整面板 URL + 一键复制、重启服务
- 设备配对卡：大号配对码（44pt 等宽）、倒计时、复制、作废
- 按钮配置：应用选择（搜索/按 Bundle ID）、重命名、上下排序、删除确认、应用缺失标记、图标
- 已配对设备：名称、配对时间、撤销配对（确认）
- 说明卡：跨空间设置指引、最小化恢复与“未确认”语义
- 手机端：配对引导、大按钮网格（竖屏 2 列/宽屏 4 列）、连接状态条（5 秒轮询 + 回前台探测）、分级反馈（正在打开/已启动/已切换/未确认/失败原因）、iOS 主屏幕元数据

## 四、本轮修复的真实缺陷

1. `NWProtocolHTTP` 在 macOS 26 SDK 不可用 → 重写为手写 HTTP 解析（TCP + 长度读取）
2. `HTTPRequestReader` 无强引用在 receive 排队后被释放，回调静默丢失 → 服务持有 activeReaders
3. 连接 ready 前调 receive 在部分环境不回调 → 改为 ready 后开始读取
4. 配对码显示被 `NavigationSplitView` 窄侧栏截断 → 重构为单列卡片布局
5. 端口被本地化显示为 `47,615` → 固定字符串输出
6. **Bundle ID 大小写**：计算器实际为 `com.apple.calculator`，原实现区分大小写导致启动成功却报 `unconfirmed` → 全链路改为大小写无关比较
7. `stop()/start()` 竞态导致偶发不监听 → 增加运行中守卫
8. 按钮排序号从 1 开始 → 修正为 0 基

## 五、已知限制（如实声明，未伪造）

- 明文 HTTP：同网段理论上可嗅探 token/配对码；仅建议可信局域网，HTTPS 为后续评估项
- 跨空间切换依赖系统设置（桌面与程序坞 → 切换到应用时切到其窗口空间，默认开）；全屏空间、多显示器不完全跟随
- 最小化窗口恢复由系统/应用决定；无法确认时反馈“unconfirmed”
- 无可见窗口的应用不会自动新建窗口
- iOS 无后台常驻；主屏幕 Web App 与 Safari localStorage 独立，需各自配对；Mac IP 变化需重新扫码、可能重新配对
- 未申请任何额外系统权限（无辅助功能、无自动化）；AppleScript 后备列为评估项
- 不修改系统设置、不开机自启、不公网暴露

## 六、验证状态

| 项目 | 状态 |
| --- | --- |
| 构建（swift build / .app 打包） | ✅ 通过 |
| 单元 + 集成 + 真实激活测试 | ✅ 24/24 |
| Mac 服务冒烟（health/panel/401/403） | ✅ 通过 |
| 界面布局截图核对 | ✅ 通过 |
| iPhone 真机配对与点击 | ⏳ 待用户验证 |
| 跨桌面空间 / 最小化 / 隐藏应用真机表现 | ⏳ 待用户验证 |
| 添加到主屏幕体验 | ⏳ 待用户验证 |

## 七、如何运行

```zsh
cd /Users/zhaojian/Desktop/MacAppControlDeck
./Build/build.sh
open build/MacAppControlDeck.app
```

Mac 窗口显示面板地址（当前网络为 `http://172.24.121.102:47615/panel/`，IP 以实际显示为准）。
手机同 Wi-Fi → Safari 打开 → Mac 端生成配对码 → 输入 → 添加按钮 → 点击。

## 八、下一阶段（任务清单 2.x）

1. 二维码（CoreImage）与地址变化提示
2. 隐藏/最小化窗口处理打磨（依据真机实测文案与行为）
3. 断线重连退避策略
4. 设备管理完善（最近活动时间、批量撤销）
5. iPad / Android 实机适配验证
6. 使用说明与故障排查正式化（README 已有草稿）
7. 评估 HTTPS 自签证书、开机自启开关（SMAppService）、AppleScript 后备

## 九、归档内容

- 本文档：`Docs/archive/2026-11-19-mvp-0.1.0/SUMMARY.md`
- 任务清单快照：`Docs/archive/2026-11-19-mvp-0.1.0/tasks-snapshot.md`
- 需求与设计（持续维护，不搬移）：`openspec/changes/add-core-control-loop/`
  - `proposal.md`、`design.md`、`tasks.md`、`specs/`（6 能力 / 36 需求）
- 使用说明：`README.md`

> 说明：OpenSpec 变更尚未执行 `openspec archive`——第一阶段闭环虽已完成，但真机验收与第二阶段任务未完成，保持活动状态便于继续跟踪。待全部验收后再归档到 `openspec/changes/archive/` 并同步能力到 `openspec/specs/`。
