# release-installer 变更（add-pet-settings-deeplink）

## ADDED Requirements

### Requirement: 安装完成后引导到桌宠设置

安装脚本 SHALL 在安装并启动成功后自动打开「设置 - 桌面宠物」；打不开时 MUST 弹窗给出手动路径。

#### Scenario: 自动打开桌宠设置

- **WHEN** 脚本确认应用进程存活
- **THEN** 执行 `open macappcontroldeck://settings/pet`（最多重试 6 次）
- **AND** 成功后弹窗说明「已打开设置 - 桌面宠物」以及「应用常驻菜单栏、关闭设置窗口不退出」

#### Scenario: 深链接失败

- **WHEN** 目标系统不认识 `macappcontroldeck://`（例如装的是旧版本）
- **THEN** 脚本仍视为安装成功，弹窗提示「菜单栏图标 -> 设置 -> 桌面宠物」手动打开

### Requirement: 未预期失败也要弹窗

安装脚本 SHALL 在退出码非零且尚未弹窗时，兜底弹出一次失败说明。

#### Scenario: 意外错误

- **WHEN** 脚本因未预期原因以非零状态退出
- **THEN** 弹窗提示退出码与 `/tmp/deck-install.log` 位置
- **AND** 不重复弹出已经显示过的失败原因
