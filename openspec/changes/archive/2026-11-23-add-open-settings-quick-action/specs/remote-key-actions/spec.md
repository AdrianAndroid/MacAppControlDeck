# remote-key-actions 变更（add-open-settings-quick-action）

## ADDED Requirements

### Requirement: 打开设置的内置操作

系统 SHALL 提供「打开设置」内置操作，允许用户把它添加为快捷操作按钮。

#### Scenario: 从按钮管理添加

- **WHEN** 用户打开「设置 → 按钮 → 添加按钮 → 添加内置操作」
- **THEN** 列表中出现「打开设置」（`settings.open`，符号 `⚙`）
- **AND** 添加后可从菜单栏快捷操作与手机面板快捷操作区触发

#### Scenario: 执行

- **WHEN** 用户点击「打开设置」按钮
- **THEN** Mac 上打开本应用设置窗口，并置于前台
- **AND** 手机端仍只发送按钮 ID，不获得任何配置读写能力
