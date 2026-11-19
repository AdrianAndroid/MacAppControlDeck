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

### Requirement: 端点契约

系统 SHALL 提供以下白名单端点，且不提供其他可写端点。

#### Scenario: 端点清单与鉴权要求

- **WHEN** 任意客户端调用服务
- **THEN** 可用端点仅限：
  - `POST /api/pair`（需一次性配对码，免 token）
  - `GET /api/health`（免 token，返回存活与应用版本，不含敏感信息）
  - `GET /api/buttons`（需 Bearer token，返回按钮列表含图标 URL 与排序）
  - `POST /api/activate`（需 Bearer token，请求体仅含按钮 ID）
  - `GET /panel/` 与静态资源（面板页面与图标）
- **AND** 未列出的路径全部返回 404，不允许动态注册新的可写端点

#### Scenario: 激活命令的请求与响应

- **WHEN** 已配对设备 POST `/api/activate` 且按钮 ID 有效
- **THEN** 服务端执行 app-control 能力并返回结构化结果：`accepted: true` 加最终状态（`activated` / `launched` / `unknown-pending`）或不明确时为 `unconfirmed`
- **AND** 区分"请求已执行"与"已确认应用切到前台"两级语义，不做无依据的确认

#### Scenario: 应用激活失败的响应

- **WHEN** 激活过程中应用未找到或系统调用失败
- **THEN** 返回明确错误码（如 `app-not-found`、`activation-failed`）与对用户可读的中文说明

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
