# 提案：聊天软件传输用的安装包

## Why

接收方电脑不能在线下载，只能通过社交软件聊天框接收文件。DMG 在部分聊天客户端会被拦或不便打开，而单独的 App 又没有安装脚本，接收方仍然要自己拖拽、去隔离。

把「App + 安装脚本 + 说明」一起打进 ZIP，聊天软件传输后解压即可双击安装，是这类场景最低摩擦的路径。

## What Changes

- 发布 ZIP 改为包含一个同名文件夹：`MacAppControlDeck-<版本>-<架构>/`，里面是
  `MacAppControlDeck.app`、`安装 MacAppControlDeck.command`、`安装说明.txt`。
- DMG 内容与 ZIP 保持一致（App + 安装脚本 + 说明 + Applications 快捷方式）。
- 安装说明新增「收到 zip 先解压，再双击安装脚本」的步骤。
- 发布结束时删除中间目录，只保留 `.app`、`.zip`、`.dmg`、`SHA256SUMS.txt`。

**非目标**：

- 不做自解压单文件、不做分卷、不上传网盘。
- 不改变安装脚本的安装/去隔离/深链接行为，也不再新增应用内功能。
- 不改变签名策略：构建机仍只用固定自签名身份。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `release-installer`：ZIP 与 DMG 都必须同时包含 App、安装脚本与安装说明，供聊天软件传输场景使用。

## Impact

- 脚本：`Build/package-release.sh`（ZIP 组装逻辑）、`Build/install-readme.txt`。
- 发布物：ZIP 内多一层文件夹，DMG 内容不变但复用同一组装目录。
- 权限/数据：无变化。
