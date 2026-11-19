# 任务清单：add-core-control-loop

## 1. 第一阶段：最小可行闭环

## 1.1 项目骨架与 host-app-shell（基础）

- [x] 1.1.1 创建 Xcode 项目 MacAppControlDeck（SwiftUI，菜单栏 + Dock 双驻留：不设 LSUIElement，本机 ad-hoc 签名）
- [x] 1.1.2 MenuBarExtra 常驻：快捷菜单（面板地址、生成配对码、打开管理窗口、退出）
- [x] 1.1.3 管理窗口骨架：状态区（监听端口/局域网地址）、配对码区、按钮管理区、设备管理区占位
- [x] 1.1.4 局域网 IPv4 枚举与面板 URL 拼接展示（暂用文本，二维码在第二阶段）

## 1.2 lan-api 服务端

- [x] 1.2.1 基于 NWListener + NWProtocolHTTP 的轻量路由器（零三方依赖）：解析方法/路径/头/Body，统一响应封装
- [x] 1.2.2 中间件：Host 头校验、请求体 4KB 上限、Content-Type 限制、CORS 预检拒绝、404 兜底
- [x] 1.2.3 `GET /api/health`（免 token，返回 {ok, app, version}）
- [x] 1.2.4 端到端自测脚本（curl）验证端点连通性与拒绝行为

## 1.3 pairing-auth

- [x] 1.3.1 配对码生成（6 位、TTL 2 分钟、3 次错误锁定、用后即焚）与防爆破频率限制
- [x] 1.3.2 `POST /api/pair`：校验配对码 → 签发 256-bit token（SecRandomCopyBytes）→ 写入 devices.json（0600 权限）
- [x] 1.3.3 token 校验中间件（Authorization: Bearer），未授权返回 401；撤销设备后立即失效
- [x] 1.3.4 设备表 JSON 原子持久化与撤销接口（服务层）
- [x] 1.3.5 单元测试：正确/错误/过期/锁定配对码；有效/无效/已撤销 token；Host 头伪造拒绝

## 1.4 button-panel-config

- [x] 1.4.1 按钮模型与 buttons.json 原子持久化（id/displayName/bundleID/pathCache/sortOrder/iconFile）
- [x] 1.4.2 本机已安装应用枚举列表（NSWorkspace，按 Bundle ID），带搜索，用于绑定选择
- [x] 1.4.3 管理窗口 UI：添加/改名/删除（确认对话框）/上下移动排序
- [x] 1.4.4 `GET /api/buttons`（需 token，返回含图标 URL）
- [x] 1.4.5 单元测试：CRUD、排序持久化、重启后恢复、文件损坏时降级

## 1.5 app-control

- [x] 1.5.1 Bundle ID 定位：urlsForApplications(withBundleIdentifier:) + 应用缺失错误
- [x] 1.5.2 未运行 → NSWorkspace.openApplication（含系统回调确认）
- [x] 1.5.3 已运行 → NSRunningApplication.activate(.activateAllWindows)，区分 launched/activated/unconfirmed 结果
- [x] 1.5.4 `POST /api/activate`（需 token，请求体仅按钮 ID）接入 app-control，返回结构化结果
- [x] 1.5.5 单元测试：按钮不存在拒绝；应用不存在错误；只对目标应用操作（不派生 shell）
- [ ] 1.5.6 手动验证：未运行启动、运行中切换前台、隐藏应用取消隐藏、最小化窗口表现（记录真实结果与限制）

## 1.6 remote-web-panel

- [x] 1.6.1 静态单页（HTML/CSS/JS）：按钮网格、竖/横屏自适应、安全区处理
- [x] 1.6.2 健康探测 + 连接状态条（已连接/未连接）+ 回前台重新探测
- [x] 1.6.3 配对引导页（输入配对码 → 存 token 到 localStorage）+ 401 时回到配对页
- [x] 1.6.4 点击流程与反馈状态："正在打开… / 已启动 / 已切换 / 已发送但未确认 / 失败原因"
- [x] 1.6.5 iOS 主屏幕元数据（apple-touch-icon 等）
- [ ] 1.6.6 手动验证（需用户配合）：iPhone Safari 打开、输入配对码、添加到主屏幕、点击按钮验证

## 1.7 第一阶段集成验收

- [ ] 1.7.1 完整闭环演练：Mac 启动 → 扫码打开 → 配对 → 添加按钮 → 手机点击 → 应用切换 → 重启程序配置仍在
- [x] 1.7.2 安全校验演练：未配对请求 401、错误配对码失败、撤销后旧 token 401、curl 直接调 /api/activate 被拒
- [ ] 1.7.3 输出《使用说明与故障排查》草稿（含明文 HTTP 风险与"切换空间"系统设置说明）

## 2. 第二阶段：完善体验

- [ ] 2.1 应用图标：NSWorkspace 图标 → 缓存 PNG → 静态端点提供；默认图标兜底
- [ ] 2.2 二维码：CoreImage CIQRCodeGenerator 生成面板地址二维码
- [ ] 2.3 隐藏/最小化窗口的合理处理与反馈文案打磨（结合 1.5.6 实测结果）
- [ ] 2.4 断线重连：面板侧退避重试与状态平滑过渡
- [ ] 2.5 配对设备管理界面完善（改名、批量撤销、最近活动时间）
- [ ] 2.6 iPad / Android 布局微调与真实设备验证
- [ ] 2.7 使用说明与故障排查正式文档（含权限说明、系统设置指引、已知限制清单）
- [ ] 2.8 （评估项）HTTPS 自签证书方案与信任引导的可行性验证，仅在必要时实施
- [ ] 2.9 （评估项）开机自启开关（SMAppService，默认关闭，点击开启）
- [ ] 2.10 （评估项）AppleScript 后备激活：仅当 1.5.6 实测系统 API 对个别应用反复失败时引入，需用户授权"自动化"权限并完善相关说明
