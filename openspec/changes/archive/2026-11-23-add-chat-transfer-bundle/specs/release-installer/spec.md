# release-installer 变更（add-chat-transfer-bundle）

## ADDED Requirements

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
