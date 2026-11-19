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
- [x] 1.5.6 真机验证完成：未运行启动、运行中切换前台、跨桌面切换、最小化恢复、JetBrains 卡死态恢复（改用 Dock 图标 AXPress；详见 design.md 实测记录）

## 1.6 remote-web-panel

- [x] 1.6.1 静态单页（HTML/CSS/JS）：按钮网格、竖/横屏自适应、安全区处理
- [x] 1.6.2 健康探测 + 连接状态条（已连接/未连接）+ 回前台重新探测
- [x] 1.6.3 配对引导页（输入配对码 → 存 token 到 localStorage）+ 401 时回到配对页
- [x] 1.6.4 点击流程与反馈状态："正在打开… / 已启动 / 已切换 / 已发送但未确认 / 失败原因"
- [x] 1.6.5 iOS 主屏幕元数据（apple-touch-icon 等）
- [x] 1.6.6 iPhone 实测完成：Safari 打开、输入配对码、点击按钮激活均验证通过

## 1.7 第一阶段集成验收

- [x] 1.7.1 完整闭环演练通过：Mac 启动 → 配对 → 添加按钮 → 手机点击 → 应用切换/空间切换 → 重启配置保留
- [x] 1.7.2 安全校验演练：未配对请求 401、错误配对码失败、撤销后旧 token 401、curl 直接调 /api/activate 被拒
- [x] 1.7.3 使用说明与故障排查已写入 README（含明文 HTTP 风险、调度中心开关、辅助功能授权、故障排查表）

## 2. 第二阶段：完善体验

- [x] 2.1 应用图标：NSWorkspace 图标 → 缓存 PNG → `/icons/` 静态端点；默认图标兜底
- [ ] 2.2 二维码：CoreImage CIQRCodeGenerator 生成面板地址二维码
- [x] 2.3 最小化窗口：Dock 图标 AXPress 走系统行为（与真人点击一致），AXRaise 路径显式取消最小化
- [ ] 2.4 断线重连：面板侧退避重试与状态平滑过渡
- [ ] 2.5 配对设备管理界面完善（改名、批量撤销、最近活动时间）
- [ ] 2.6 iPad / Android 布局微调与真实设备验证
- [x] 2.7 正式文档完成：README（功能/构建/首次配置/安全边界/已知限制/故障排查/项目结构）+ openspec design 实测记录
- [x] 2.8 评估结论：暂不实施。明文 HTTP 限于可信局域网，风险已在 README 声明；HTTPS 作为后续候选
- [ ] 2.9 （评估项）开机自启开关（SMAppService，默认关闭，点击开启）
- [x] 2.10 评估结论：不实施。实测 AppleScript activate/reopen 对卡死态无效（见 design.md 实测记录），已由 Dock 图标 AXPress 取代

## 3. 激活可靠性重构（2026-11-19 追加）

- [x] 3.1 定位根因：后台进程激活只标记前台、不切空间；JetBrains 应用会进入"卡死态"
- [x] 3.2 采用「Dock 图标 AXPress」作为首选激活路径（等价真人点击 Dock，实测跨空间与卡死态均生效）
- [x] 3.3 成功判定改为"目标应用成为前台"；窗口可见性仅记日志（进程内 CGWindowList 数据不可靠）
- [x] 3.4 移除"温和重启应用"方案（不杀 App）
- [x] 3.5 稳定自签名证书（TCC 授权跨重建保留）+ UI 权限状态灯与一键跳转授权
- [x] 3.6 应用图标（AppIcon.icns + Build/make-icon.swift）
- [x] 3.7 文档归档：README 重写、design.md 实测记录、调度中心开关前置说明
