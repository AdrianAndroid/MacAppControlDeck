# remote-web-panel 变更（fix-screen-safe-area-padding）

## MODIFIED Requirements

### Requirement: 视口铺满与可调内边距

副屏内边距 SHALL 只由 Mac 端设置的上 / 右 / 下 / 左数值决定，`env(safe-area-inset-*)` MUST NOT 再隐式叠加。

#### Scenario: 四边为 0

- **WHEN** 设置里四边内边距都是 0
- **THEN** 内容四边贴住视口，包括刘海 / 圆角设备横屏时
- **AND** 不再出现左右或底部被 safe-area 撑开的空白

#### Scenario: 需要避让刘海

- **WHEN** 用户希望避开刘海、圆角或 home indicator
- **THEN** 在对应边设置内边距即可，页面不再自动补

#### Scenario: 控制条跟随

- **WHEN** 上内边距不为 0
- **THEN** 顶部控制条下移到 `上内边距 + 2u`，不压在内容上
