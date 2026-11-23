# release-installer 变更（add-friendly-installer）

## ADDED Requirements

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
