# remote-web-panel Delta

## MODIFIED Requirements

### Requirement: 副屏只读与配置下发

副屏页面 SHALL 只读渲染，尺寸、宠物卡片、常亮等配置全部由 Mac 端 `/api/screen/display` 下发。

#### Scenario: 关闭宠物卡片

- **WHEN** 用户在 设置 → 副屏 关闭「在副屏显示底部宠物卡片」
- **THEN** 横屏副屏不再渲染底部宠物卡片，时钟区高度增加
- **AND** 重新打开开关后立即恢复，无需刷新页面

#### Scenario: 默认可见

- **WHEN** 升级前的配置里没有 `petVisible`
- **THEN** 按 `true` 处理，横屏仍显示宠物卡片
