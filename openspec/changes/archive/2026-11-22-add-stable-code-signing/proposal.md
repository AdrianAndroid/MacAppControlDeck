# add-stable-code-signing

## Why

本机安装 v0.2.0 release 包后，辅助功能、输入监控、屏幕录制和自动化授权再次被要求授予。原因是 release 打包脚本强制使用 ad-hoc 签名，而本机开发构建使用 `MacAppControlDeck Self-Signed`。ad-hoc 的 designated requirement 只有 `cdhash`，每次重建或重装都会变化，TCC 因此把新包当成另一个应用。

这会造成两个问题：

- 用户每次安装新构建都要重新授权，频繁且不可接受。
- 系统设置里可能保留旧条目，表现为“开关是开的，但授权不生效”。

## What Changes

- 固定本机签名身份为 `MacAppControlDeck Self-Signed`（SHA-1 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`）。
- 新增 `Build/signing.sh`，集中处理身份解析、签名、DR 校验和 ad-hoc 拒绝。
- `Build/build.sh` 与 `Build/package-release.sh` 默认使用固定自签名身份；只有显式设置 `DECK_ALLOW_ADHOC=1` 才允许 ad-hoc。
- 新增 `Build/verify-signing.sh`，用于检查安装包或构建产物的签名与 designated requirement。
- 更新 README：本机构建/安装流程、发布包签名说明、授权排障。
- 更新 `AGENTS.md`，把“固定签名、禁止本地 ad-hoc、构建后校验 DR”写成项目级规则。

## Capabilities

- `stable-code-signing`：本机与本地发布产物必须使用固定签名身份，TCC 授权跨重建保持匹配。

## Impact

- `Build/signing.sh`（新增）
- `Build/verify-signing.sh`（新增）
- `Build/build.sh`
- `Build/package-release.sh`
- `README.md`
- `AGENTS.md`
- `openspec/specs/stable-code-signing/spec.md`（归档时新增）

## 非目标

- 不申请 Developer ID，不做 Apple 公证。
- 不修改系统 TCC 数据库，不自动调用 `tccutil`。
- 不改变应用功能、Bundle ID 或权限申请时机。
- 不承诺公开分发用户首次打开无 Gatekeeper 提示；未公证包仍需右键打开。
