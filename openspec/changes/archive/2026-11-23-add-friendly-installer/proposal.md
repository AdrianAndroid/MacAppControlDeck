# 提案：发布包内置双击安装脚本

## Why

当前发布包是未公证的自签名 App，通过微信等方式传到对方 Mac 后会带上 `com.apple.quarantine`，双击常被 Gatekeeper 静默拦下。对方是电脑小白，不会 `xattr -dr`、`codesign`、`spctl` 这些命令，也无法解释「为什么点了没反应」。

同时这个 App 是 `LSUIElement` 菜单栏应用，没有 Dock 图标也没有主窗口，即使安装成功也容易被误判为「没反应」。

目标：让接收方只需双击一个文件，脚本自动完成安装、解除隔离、启动与结果确认；任何失败都弹窗说明原因，而不是静默退出。

## What Changes

- 新增 `Build/install-friendly.command`：双击运行，自动完成
  1. 定位同一目录（或已挂载 DMG、下载目录、桌面）中的 `MacAppControlDeck.app`
  2. 校验芯片架构，Apple 芯片与 Intel 包不匹配时直接弹窗说明
  3. 关闭旧实例，`ditto` 复制到 `/Applications`，无权限时用管理员授权重试
  4. 递归移除 `com.apple.quarantine` / `com.apple.provenance`
  5. `codesign --verify` 不通过时，只在对方机器上用本机临时签名修复
  6. 启动应用并确认进程存活；成功弹窗说明「去菜单栏找图标」和「如何打开桌宠」
  7. 失败时弹窗 + 输出 `/tmp/deck-install.log` 与最近崩溃报告摘要
- `Build/package-release.sh` 在 DMG 中额外放入 `安装 MacAppControlDeck.command`（可执行）与 `安装说明.txt`。
- 本机构建/签名流程不变：仍然只用固定自签名身份，禁止在构建机降级 ad-hoc；脚本里的临时签名只发生在对方机器、且仅作为传递后签名损坏的兜底。

**非目标**：

- 不做公证，也不引入 Apple Developer ID。
- 不新增应用内功能、不新增模块入口（属于发布方式变更，无用户可见新窗口）。
- 不改变 App 本身的行为、权限申请顺序或数据目录。

## Capabilities

### New Capabilities

- `release-installer`：发布包内的双击安装脚本及其成功/失败提示要求。

### Modified Capabilities

- `stable-code-signing`：补充「接收方机器允许安装脚本在 quarantine 清除后做本机临时签名兜底，构建机仍禁止 ad-hoc」的边界。

## Impact

- 代码/脚本：`Build/install-friendly.command`、`Build/install-readme.txt`、`Build/package-release.sh`。
- 规范：归档时新增 `openspec/specs/release-installer/spec.md`，并同步 `openspec/specs/stable-code-signing/spec.md`。
- 发布物：DMG 内多两个文件；ZIP 与校验和不变。
- 权限/数据：脚本会在对方机器请求一次管理员授权（仅在 `/Applications` 无写权限时）与一次「打开脚本」确认。
