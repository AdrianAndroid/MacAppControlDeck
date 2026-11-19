# host-app-shell Specification

## Purpose
TBD - created by archiving change add-core-control-loop. Update Purpose after archive.

## Requirements

### Requirement: 菜单栏与 Dock 双驻留宿主

系统 SHALL 同时提供 macOS 菜单栏驻留（MenuBarExtra）与 Dock 应用图标双驻留形态，管理能力通过菜单与辅助窗口触达。

#### Scenario: 启动后常驻

- **WHEN** Mac 端程序启动
- **THEN** 菜单栏出现程序图标，点击显示快捷菜单（服务地址、生成配对码、打开管理窗口、退出）
- **AND** Dock 同时显示应用图标，便于用户选中程序强制退出或切换

#### Scenario: 激活他人应用时不干扰

- **WHEN** 用户在手机端请求激活其他应用
- **THEN** 本程序尽力不与目标应用争夺前台焦点

### Requirement: 服务地址与二维码展示

系统 SHALL 在 Mac 端显示面板的局域网访问地址与对应二维码，便于手机扫码打开。

#### Scenario: 展示局域网地址

- **WHEN** 用户打开 Mac 端管理窗口或菜单
- **THEN** 显示面板 URL（基于本机当前局域网 IPv4 与实际监听端口）和可扫描的二维码
- **AND** 多网卡或地址变化时显示实际可达的地址列表

### Requirement: 按钮管理界面

系统 SHALL 在 Mac 端提供按钮管理界面，支持选择已安装应用绑定按钮、改名、删除、排序。

#### Scenario: 从已安装应用中选择

- **WHEN** 用户添加或修改按钮
- **THEN** 提供本机已安装应用的选择列表（按 Bundle ID），支持搜索
- **AND** 被绑定应用已删除时，该按钮标记"应用缺失"并允许重新绑定

### Requirement: 配对与设备管理界面

系统 SHALL 在 Mac 端提供配对码生成入口和已配对设备列表（含撤销）。

#### Scenario: 查看与撤销设备

- **WHEN** 用户打开设备管理页
- **THEN** 列出每个已配对设备的名称、配对时间，提供撤销按钮（撤销前确认）
- **AND** 撤销后该设备立即失去访问权限

### Requirement: 权限按需请求与说明

系统 SHALL 只在真正需要某权限时向用户说明并请求，且不在用户操作前修改任何系统设置。

#### Scenario: 权限说明

- **WHEN** 用户查看权限或帮助说明
- **THEN** 明确列出：第一阶段仅使用 NSWorkspace/NSRunningApplication 系统接口，无需任何额外权限
- **AND** 说明 AppleScript 后备激活为后续评估项，届时才需要"自动化"权限（系统设置 > 隐私与安全性 > 自动化），使用前会先说明原因
- **AND** 不会自动配置开机自启；如提供自启开关（SMAppService），必须由用户主动开启

#### Scenario: 不修改系统设置

- **WHEN** 程序在任何阶段运行
- **THEN** 不开启远程登录、不写入系统偏好、不安装 LaunchAgent，除非用户通过程序内开关明确开启

### Requirement: 退出与不可用感知

系统 SHALL 在程序退出后停止服务，使手机端能通过健康检查感知不可用。

#### Scenario: 程序退出

- **WHEN** 用户从菜单栏退出 Mac 端程序
- **THEN** HTTP 服务关闭，手机端下一次探测显示"Mac 未连接"
- **AND** Mac 锁屏或休眠导致的不可达同样由手机端探测发现，程序不承诺休眠时仍可控制
