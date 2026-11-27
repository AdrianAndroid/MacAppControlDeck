# lan-api Specification

## Purpose
TBD - created by archiving change add-core-control-loop. Update Purpose after archive.

## Requirements

### Requirement: 局域网 HTTP 服务

系统 SHALL 在 Mac 本机监听一个可配置端口的 HTTP 服务，仅绑定局域网接口，不主动向公网暴露。

#### Scenario: 服务启动

- **WHEN** Mac 端程序启动且用户未修改端口
- **THEN** 使用 Network.framework（NWListener + NWProtocolHTTP）在默认端口监听，实现零三方依赖
- **AND** 端口被占用时自动换用下一个可用端口并在 UI 呈示实际地址

#### Scenario: 程序退出后不可达

- **WHEN** Mac 端程序退出或端口停止监听
- **THEN** 所有端点不可达，手机端健康检查失败并显示"Mac 未连接"

### Requirement: 服务地址与网络变化刷新

系统 SHALL 在网络路径变化后刷新当前面板地址，并允许通过二维码在新设备上打开面板。

#### Scenario: 切换 Wi-Fi 后自动刷新
- **WHEN** Mac 从一个 Wi-Fi 切换到另一个 Wi-Fi
- **THEN** `NWPathMonitor` 触发后自动重算当前 IP
- **AND** 菜单栏「电脑控制」再次打开时显示新 IP，不需要重启 App

#### Scenario: 扫码打开
- **WHEN** 打开 设置 → 电脑控制 → 服务
- **THEN** 展示当前面板地址的二维码，手机相机扫码即可打开
- **AND** 二维码本地生成，不上传 URL 或任何数据
- **AND** IP 变化后旧地址/旧二维码失效，需要重新扫码

#### Scenario: 内置入口
- **WHEN** 从按钮管理添加「打开网络地址」
- **THEN** 点击后刷新地址并打开设置 → 电脑控制 → 服务
- **AND** 同步出现在菜单栏快捷操作与手机面板快捷操作

### Requirement: 副屏在线登记端点

系统 SHALL 提供免 token 的 `POST /api/screen/presence`，仅用于副屏浏览器登记展示。

#### Scenario: 合法登记
- **WHEN** 请求体为 `{"id":"screen-..."}`，且 ID 匹配 `^[A-Za-z0-9_-]{8,64}$`
- **THEN** 返回 204，记录 ID、由 User-Agent 推导的名称、首次/最近时间
- **AND** 记录写入本机 `screen_clients.json`，权限 0600

#### Scenario: 非法登记
- **WHEN** ID 缺失、超长或包含路径字符
- **THEN** 返回 400，不写入任何记录

#### Scenario: 无操作权限
- **WHEN** 调用方只有副屏登记记录或未配对
- **THEN** 仍不能访问 `/api/buttons`、`/api/activate` 等业务端点
- **AND** 登记接口不返回 token，也不暴露任何设备凭证

#### Scenario: 容量与过期
- **WHEN** 登记数量超过 20 或记录超过 7 天未更新
- **THEN** 自动清理最旧记录，避免无限增长

### Requirement: 端点契约

系统 SHALL 提供以下白名单端点，且不提供其他可写端点。

#### Scenario: 端点清单与鉴权要求

- **WHEN** 任意客户端调用服务
- **THEN** 可用端点仅限：
  - `POST /api/pair`（需一次性配对码，免 token）
  - `GET /api/health`（免 token，返回存活与应用版本，不含敏感信息）
  - `GET /api/buttons`（需 Bearer token，返回按钮列表含类型、图标/组合符号、分组与排序；应用顺序与桌宠快捷栏共用）
  - `POST /api/activate`（需 Bearer token，请求体仅含按钮 ID；应用按钮执行启动/激活并记录一次应用点击，快捷操作按钮执行按键注入）
  - `GET /panel/` 与静态资源（面板页面与图标）
  - `GET /screen/`、`/screen/icons/`（只读副屏页面与图标）
  - `POST /api/screen/presence`（免 token，副屏在线登记，仅展示用）
- **AND** 未列出的路径全部返回 404，不允许动态注册新的可写端点

#### Scenario: 激活命令的请求与响应

- **WHEN** 已配对设备 POST `/api/activate` 且按钮 ID 有效
- **THEN** 服务端按按钮类型路由：
  - 应用按钮：返回 `accepted: true` 与最终状态（`activated` / `launched` / `unconfirmed`）
  - 快捷操作按钮：返回 `accepted: true` 与 `sent`（按键事件已注入）或明确失败原因
- **AND** 区分"请求已执行"与"目标应用已确认响应"两级语义，不做无依据的确认
- **AND** 响应包含按钮类型，便于面板展示对应文案

#### Scenario: 应用激活失败的响应

- **WHEN** 激活过程中应用未找到或系统调用失败
- **THEN** 返回明确错误码（如 `app-not-found`、`activation-failed`）与对用户可读的中文说明

#### Scenario: 快捷键注入失败的响应

- **WHEN** 快捷操作因未授权辅助功能、安全输入模式或系统拒绝而未能注入
- **THEN** 返回明确错误码（如 `accessibility-required`、`secure-input`、`injection-failed`）与中文说明
- **AND** 不返回成功状态

### Requirement: 静态面板托管

系统 SHALL 通过同一 HTTP 服务托管手机端面板的静态资源（HTML/CSS/JS/图标），使手机无需独立安装任何应用。

#### Scenario: 手机打开面板

- **WHEN** 同一局域网内的手机用 Safari 打开 `http://<Mac IP>:<端口>/panel/`
- **THEN** 面板页面正常加载，随后由面板自身要求配对或携带 token 获取按钮列表

### Requirement: 明文 HTTP 风险声明

系统 SHALL 在文档与界面中如实声明局域网明文 HTTP 通信可被同网段设备窃听的风险与应对边界。

#### Scenario: 用户查看安全说明

- **WHEN** 用户阅读 Mac 端说明或 README
- **THEN** 明确写明：HTTP 明文流经同网段可被嗅探到 token 与配对码；本设计以"短时配对码 + 可撤销 token + 白名单端点"控制危害半径，默认仅建议在可信家庭局域网使用
- **AND** 声明这是第一版的安全边界，HTTPS（自签证书）列为后续可评估项

### Requirement: 日志最小化

系统 SHALL 在日志中不记录 token、配对码与请求体内容，只记录时间、端点与结果的脱敏摘要。

#### Scenario: 日志输出

- **WHEN** 任意请求被处理并写日志
- **THEN** 日志仅含时间戳、端点路径、结果状态（成功/失败/未授权）与设备名
- **AND** 不出现 token 值、配对码值或完整请求体
