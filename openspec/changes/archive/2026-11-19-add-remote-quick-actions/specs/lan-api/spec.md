# lan-api 规格增量（delta）

## MODIFIED Requirements

### Requirement: 端点契约

系统 SHALL 提供以下白名单端点，且不提供其他可写端点。

#### Scenario: 端点清单与鉴权要求

- **WHEN** 任意客户端调用服务
- **THEN** 可用端点仅限：
  - `POST /api/pair`（需一次性配对码，免 token）
  - `GET /api/health`（免 token，返回存活与应用版本，不含敏感信息）
  - `GET /api/buttons`（需 Bearer token，返回按钮列表含类型、图标/组合符号、分组与排序）
  - `POST /api/activate`（需 Bearer token，请求体仅含按钮 ID；应用按钮执行启动/激活，快捷操作按钮执行按键注入）
  - `GET /panel/` 与静态资源（面板页面与图标）
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
