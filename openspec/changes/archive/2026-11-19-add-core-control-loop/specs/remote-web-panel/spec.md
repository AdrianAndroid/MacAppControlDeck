# remote-web-panel 规格增量

## ADDED Requirements

### Requirement: 按钮面板主界面

手机端 SHALL 以大按钮网格展示已配置的应用按钮，每个按钮清晰显示图标与名称，适合手指点击。

#### Scenario: 正常展示按钮

- **WHEN** 已配对设备加载面板并成功获取按钮列表
- **THEN** 页面显示按钮网格，按钮足够大（点击区域建议 ≥ 72pt），有图标、名称
- **AND** 按列表排序展示，页面整体简洁，无复杂管理后台

#### Scenario: 竖屏与横屏自适应

- **WHEN** 用户在 iPhone 竖屏或横屏使用面板
- **THEN** 布局随屏幕方向自适应（竖屏 2 列、横屏 3–4 列），内容不受刘海/安全区遮挡
- **AND** 同一页面在 iPad 与常见 Android 浏览器可用

### Requirement: 连接状态展示

面板 SHALL 实时探测 Mac 端健康状态并显示连接状态，且在不可达时如实提示。

#### Scenario: 探测健康状态

- **WHEN** 面板加载或从后台返回前台
- **THEN** 调用 `GET /api/health` 探测，显示"已连接 / Mac 未连接"
- **AND** Mac 端退出或手机断网时，状态转为"Mac 未连接"并提示检查局域网

#### Scenario: 配对引导

- **WHEN** 面板加载后未检测到有效凭证或凭证被撤销（401）
- **THEN** 显示引导界面，请用户输入 Mac 端显示的配对码完成配对
- **AND** 不使用旧 token 反复请求

### Requirement: 点击按钮的操作反馈

面板 SHALL 对每次点击给出明确反馈，并区分"请求已发送"与"应用已确认激活"两级语义。

#### Scenario: 请求已发送

- **WHEN** 用户点击某按钮且请求已发出
- **THEN** 该按钮立即显示"正在打开…"的进行中状态

#### Scenario: 请求已确认

- **WHEN** 服务端返回成功且状态为 `launched` 或 `activated`
- **THEN** 反馈"已启动"或"已切换"，随后按钮状态恢复空闲

#### Scenario: 服务端无法确认

- **WHEN** 服务端返回 `unconfirmed`（如已激活但无法确认窗口状态）
- **THEN** 反馈"已发送激活请求，但未能确认窗口状态"，不显示虚假的"已切换"

#### Scenario: 失败反馈

- **WHEN** 服务端返回 `app-not-found`、`activation-failed` 或网络失败
- **THEN** 显示对应中文错误说明（如"应用未找到（可能已卸载）"），不重试到无限循环

### Requirement: iOS 主屏幕支持

面板 SHALL 提供添加到 iPhone/iPad 主屏幕所需的基本 Web App 元数据与图标。

#### Scenario: 添加到主屏幕

- **WHEN** 用户在 Safari 中选择"添加到主屏幕"
- **THEN** 面板提供 `apple-mobile-web-app-capable`、`apple-mobile-web-app-status-bar-style`、`apple-touch-icon`、`viewport-fit=cover`、`theme-color` 等元数据
- **AND** 从主屏打开时以无浏览器工具栏的独立窗口呈现

### Requirement: 平台限制的如实呈现

面板 SHALL 按平台实际能力设计，在说明中告知 iOS 的后台与发现限制，不做不可兑现的承诺。

#### Scenario: 回到前台时重新探测

- **WHEN** Web App 从后台返回
- **THEN** 立即重新探测健康状态并按结果显示连接状态
- **AND** 说明文档明确：iOS 无后台常驻，锁屏/切后台后回来需重新探测；Mac 休眠或程序退出时面板不可用
