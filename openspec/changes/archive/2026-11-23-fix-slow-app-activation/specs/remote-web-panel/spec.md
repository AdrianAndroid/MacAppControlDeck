# remote-web-panel 变更（fix-slow-app-activation）

## MODIFIED Requirements

### Requirement: 手机面板按钮请求超时

手机面板 SHALL 为 app 类型按钮设置与服务端激活耗时预算对齐的请求超时，避免服务仍在执行时前端提前放弃。

#### Scenario: 服务端正执行多策略激活

- **WHEN** 手机点击 app 按钮，服务端激活在多条策略间回退但仍在执行
- **THEN** 前端请求超时为 12 秒，覆盖服务端最坏 8.5 秒加 HTTP 开销
- **AND** 不在 20 秒时才放弃，也不在服务端完成前提前放弃
