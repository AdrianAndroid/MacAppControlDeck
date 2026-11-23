# settings-deeplink Specification

## Purpose

定义 `macappcontroldeck://` 深链接：让安装脚本或外部命令直接打开设置窗口并定位到指定设置页，避免让不熟悉菜单层级的使用者自己找入口。

## Requirements

### Requirement: 设置页深链接

应用 SHALL 注册 `macappcontroldeck` URL scheme，并通过该 scheme 打开设置窗口并定位到指定设置页。

#### Scenario: 打开桌宠设置

- **WHEN** 外部执行 `open macappcontroldeck://settings/pet`
- **THEN** 应用被激活，设置窗口出现并选中「桌面宠物」页
- **AND** 若应用此前未运行，则先完成启动再打开设置，不出现空窗口

#### Scenario: 查询参数形式

- **WHEN** 外部执行 `open "macappcontroldeck://settings?tab=pet"`
- **THEN** 与路径形式等效，打开桌宠设置页

#### Scenario: 未知页面

- **WHEN** URL 中的目标页名称不在支持列表中
- **THEN** 应用忽略该请求，不打开设置窗口，也不崩溃

#### Scenario: 支持的页面

- **WHEN** URL 使用 general / menu / modules / capture / sketch / calendar / pet / buttons / devices / service / about
- **THEN** 设置窗口打开并选中对应页面
