# remote-web-panel 变更（revert-screen-pet-cat-chase）

## REMOVED Requirements

### Requirement: 宠物卡猫追老鼠

**原因**：真机移动时角色边缘持续闪烁，观感不可接受；先整体移除，后续另开变更修复
（补 `image-rendering: pixelated`、位移取整或改用整帧渲染）。

**迁移**：无。副屏宠物卡恢复为单只游走。

#### Scenario: 页面不再出现追逐层

- **WHEN** 副屏加载
- **THEN** DOM 中不存在 `#petChase`
- **AND** 宠物卡只有原有单只宠物在游走

#### Scenario: 配置不再下发追逐字段

- **WHEN** 请求 `GET /api/screen/display`
- **THEN** 响应中不含 `petChase` 与 `petChaseInterval`
