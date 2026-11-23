# remote-web-panel 变更（add-panel-force-refresh）

## ADDED Requirements

### Requirement: 状态徽标强制刷新

面板 SHALL 允许用户点击连接状态徽标触发一次强制刷新，并用带缓存参数的新地址重载面板。

#### Scenario: 点击已连接

- **WHEN** 用户点击右上角「已连接」徽标
- **THEN** 徽标显示「刷新中…」并禁止重复触发
- **AND** 页面重载为 `/panel/?v=<最新面板版本>&t=<时间戳>`
- **AND** 重载后恢复显示最新连接状态与按钮列表

#### Scenario: 未连接时点击

- **WHEN** 徽标显示「Mac 未连接」时被点击
- **THEN** 同样执行一次刷新；若 Mac 端恢复在线，刷新后显示「已连接」

#### Scenario: 重复点击

- **WHEN** 刷新过程中再次点击徽标
- **THEN** 忽略本次点击，不产生额外导航

#### Scenario: 键盘可达

- **WHEN** 徽标获得焦点并按下 Enter 或 Space
- **THEN** 与点击行为一致

#### Scenario: 保留登录状态

- **WHEN** 强制刷新完成
- **THEN** 已配对的 `deck_token` 仍有效，不回到配对页
