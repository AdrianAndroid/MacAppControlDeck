# lan-api 变更（add-device-presence-and-pairing-qr）

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: 端点契约

免 token 端点除 `/api/health`、`/api/pair`、`/panel/` 外，新增只读副屏遥测 `/api/screen/presence` 与 `/screen/` 及其静态资源。
