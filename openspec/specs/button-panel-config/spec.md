# button-panel-config Specification

## Purpose
TBD - created by archiving change add-core-control-loop. Update Purpose after archive.

## Requirements

### Requirement: 按钮的创建与绑定应用

用户 SHALL 能在 Mac 端新增按钮，并通过已安装应用的选择器把按钮绑定到一个目标应用。

#### Scenario: 新增按钮并选择应用

- **WHEN** 用户在 Mac 端点击"添加按钮"并从应用列表（按 Bundle ID 枚举本机已安装应用）选择一个应用
- **THEN** 创建一条按钮配置：id（UUID）、显示名、Bundle ID、应用路径缓存、排序号
- **AND** 按钮显示名默认取应用显示名，可随后修改

### Requirement: 按钮的修改与删除

用户 SHALL 能修改按钮显示名、重新绑定应用，以及删除按钮；删除前必须给出明确确认。

#### Scenario: 删除前确认

- **WHEN** 用户点击删除某个按钮
- **THEN** 弹出确认对话框，显示按钮名称与绑定的应用名
- **AND** 只有用户确认后才删除，取消则不做任何变更

### Requirement: 按钮排序

用户 SHALL 能调整按钮在面板中的显示顺序。

#### Scenario: 上移或下移

- **WHEN** 用户在 Mac 端对某按钮执行上移/下移（或拖拽排序）
- **THEN** 按钮的排序号更新并写回持久化文件，手机端刷新后按新顺序展示

### Requirement: 应用图标自动填充

系统 SHALL 尽可能自动获取并缓存目标应用的图标作为按钮图标；获取失败时使用明确的默认图标。

#### Scenario: 图标获取成功

- **WHEN** 绑定的应用在本机存在且有图标
- **THEN** 通过 `NSWorkspace` 图标 API 生成位图并缓存为本地文件，HTTP 面板可通过端点访问该图标
- **AND** 图标以缓存文件复用，不重复读取应用包

#### Scenario: 图标获取失败

- **WHEN** 应用不存在、图标缺失或生成失败
- **THEN** 按钮使用内置默认图标，面板上仍清晰显示按钮名称

### Requirement: 配置本地持久化

系统 SHALL 把按钮配置以原子方式写入 Mac 本地 JSON 文件，程序重启后完整保留。

#### Scenario: 重启后配置仍在

- **WHEN** Mac 端程序退出后再次启动
- **THEN** 按钮列表、顺序、名称与图标绑定与退出前一致
- **AND** 配置文件损坏或缺失时程序以空列表启动并给出提示，不崩溃

#### Scenario: 原子写入

- **WHEN** 任意一次配置保存
- **THEN** 先写临时文件再原子 rename 覆盖，避免写入中断造成损坏

### Requirement: 配置入口在 Mac 端（第一版）

第一版 SHALL 把按钮的增删改与排序全部放在 Mac 端管理界面；手机端只读已配置的按钮列表。

#### Scenario: 手机端只读

- **WHEN** 任意已配对设备请求按钮列表或系统预置面板
- **THEN** 手机端没有修改按钮配置的入口；激活命令是唯一可写端点
- **AND** 后续如要在手机端开放管理，必须作为新的受控端点另行评审
