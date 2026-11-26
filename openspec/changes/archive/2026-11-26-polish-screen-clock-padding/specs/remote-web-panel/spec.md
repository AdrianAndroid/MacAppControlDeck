# remote-web-panel Delta

## ADDED Requirements

### Requirement: 副屏时钟卡留白

副屏时钟卡 SHALL 让表盘四周留白相等且不贴边框，不再显示底部日期行。

#### Scenario: 任意宽高比

- **WHEN** 副屏以横屏 / 竖屏任一方向打开
- **THEN** 表盘半径 = `min(画布宽, 画布高)/2 − 2.4u`，四边留白等距
- **AND** 表盘在卡片内水平与垂直居中

#### Scenario: 不再有日期行

- **WHEN** 副屏渲染时钟卡
- **THEN** 卡片内只有表盘，没有 `THU 26 NOV` 之类的底部文字
