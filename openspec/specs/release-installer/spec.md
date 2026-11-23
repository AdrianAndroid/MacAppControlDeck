# release-installer Specification

## Purpose

定义发布 DMG 内的双击安装脚本与安装说明：让不熟悉命令行的接收方也能完成安装、解除 macOS 下载隔离、启动应用，并在失败时看到可读原因。

## Requirements

### Requirement: 双击安装脚本

发布 DMG SHALL 内置可执行的双击安装脚本，自动把 App 安装到 `/Applications` 并启动；任一失败环节必须通过弹窗给出可读原因，不得静默退出。

#### Scenario: 正常安装

- **WHEN** 接收方双击 DMG 内的 `安装 MacAppControlDeck.command`
- **THEN** 脚本定位同目录的 `MacAppControlDeck.app`，关闭旧实例并复制到 `/Applications`
- **AND** 递归移除 quarantine 与 provenance 属性，校验签名后在签名不完整时用本机临时签名修复
- **AND** 启动 App，确认进程存活后弹窗提示「已装好，去菜单栏找图标，桌宠可手动打开」

#### Scenario: 芯片不匹配

- **WHEN** 机器架构与应用二进制架构不一致（Apple 芯片装 Intel 包，或反之）
- **THEN** 脚本停止安装并弹窗说明需要哪种架构的安装包

#### Scenario: 缺少安装包

- **WHEN** 脚本同目录、下载目录、桌面与已挂载卷中都找不到 `MacAppControlDeck.app`
- **THEN** 脚本退出码为 1，弹窗提示把脚本与 App 放在同一文件夹后重试

#### Scenario: 启动失败

- **WHEN** 复制成功但启动后进程不存在
- **THEN** 脚本弹窗提示把终端内容或 `/tmp/deck-install.log` 发给发送人
- **AND** 日志中附带 `spctl` 判定与最近崩溃报告摘要

### Requirement: 安装说明文件

发布 DMG SHALL 附带纯文本安装说明，覆盖双击步骤、右键「打开」兜底、菜单栏图标位置、桌宠入口与卸载方式。

#### Scenario: 阅读说明

- **WHEN** 接收方打开 `安装说明.txt`
- **THEN** 能看到双击步骤、被系统拦截时的右键「打开」做法、芯片不匹配的提示与卸载方法

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

### Requirement: 聊天传输可用的 ZIP

发布 ZIP SHALL 包含 App、安装脚本与安装说明，解压后得到同名文件夹，供不能在线下载、只能通过聊天软件接收文件的机器使用。

#### Scenario: 解压 zip 后安装

- **WHEN** 接收方把聊天软件收到的 zip 解压
- **THEN** 得到 `MacAppControlDeck-<版本>-<架构>/` 文件夹
- **AND** 文件夹内包含 `MacAppControlDeck.app`、`安装 MacAppControlDeck.command`、`安装说明.txt`

#### Scenario: 与 DMG 内容一致

- **WHEN** 比较同一版本的 ZIP 文件夹与 DMG 挂载内容
- **THEN** 两者都包含 App、安装脚本与安装说明（DMG 额外带 Applications 快捷方式）
- **AND** 安装脚本行为一致：安装到 `/Applications`、去隔离、启动、打开桌宠设置
