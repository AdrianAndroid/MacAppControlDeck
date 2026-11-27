# lan-api 变更（unify-app-order-with-pet-dock）

## MODIFIED Requirements

### Requirement: 端点契约

系统 SHALL 提供以下白名单端点，且不提供其他可写端点。

#### Scenario: 端点清单与鉴权要求

- **WHEN** 已配对设备请求业务端点
- **THEN** 仅下列路径可用：
  - `GET /api/buttons`（需 Bearer token，返回按钮列表含类型、图标/组合符号、分组与排序）
  - `POST /api/activate`（需 Bearer token，请求体仅含按钮 ID；应用按钮执行启动/激活并记录一次应用点击，快捷操作按钮执行按键注入）
  - `GET /panel/` 与静态资源（面板页面与图标）
  - `GET /screen/`、`/screen/icons/`（只读副屏页面与图标）
  - `POST /api/screen/presence`（免 token，副屏在线登记，仅展示用）
- **AND** 未列出的路径全部返回 404，不允许动态注册新的可写端点

#### Scenario: 按钮顺序

- **WHEN** 面板读取 `GET /api/buttons`
- **THEN** 应用按钮按共享排序服务（点击频率 / 手动 / 最近使用）的顺序返回
- **AND** 该顺序在 5 秒防抖到期前保持不变，与桌宠快捷栏一致

#### Scenario: 激活命令的请求与响应

- **WHEN** 已配对设备 POST `/api/activate` 且按钮 ID 有效
- **THEN** 服务端按按钮类型路由：
  - 应用按钮：记录一次应用点击，返回 `accepted: true` 与最终状态（`activated` / `launched` / `unconfirmed`）
  - 快捷操作按钮：返回 `accepted: true` 与 `sent`（按键事件已注入）或明确失败原因
- **AND** 区分"请求已执行"与"目标应用已确认响应"两级语义，不做无依据的确认
- **AND** 响应包含按钮类型，便于面板展示对应文案
