# remote-web-panel Delta

## ADDED Requirements

### Requirement: 天气卡底部署名

天气卡底部 SHALL 只占一行，把城市、更新时间与数据源用 `·` 连成一句，字号与颜色一致，且底栏高度随内容自适应。

#### Scenario: 一行署名

- **WHEN** 副屏天气正常渲染
- **THEN** 卡片底部只有一行 `城市 · 更新 HH:mm · 和风天气`
- **AND** 三者同为 `--muted` 与同一字号，城市不再放大或右对齐

#### Scenario: 底栏不占固定高度

- **WHEN** 副屏为横屏任一档尺寸
- **THEN** 底栏高度由这一行决定，5 天预报区因此获得更多高度
- **AND** 数据过期时该行末尾追加橙色「已过期」

#### Scenario: 天气关闭

- **WHEN** 天气未配置或加载失败
- **THEN** 底栏不渲染城市占位文字
