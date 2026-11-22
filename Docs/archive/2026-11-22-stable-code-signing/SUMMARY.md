# 固定代码签名与 TCC 授权（2026-11-22）

## 需求背景

安装 v0.2.0 release 包后，辅助功能、输入监控、屏幕录制和自动化授权再次被要求授予。排查确认：

- 本机开发构建使用 `MacAppControlDeck Self-Signed`，DR 为 `identifier + certificate root`，重建后授权可保持。
- release 打包脚本强制 `codesign --sign -`，生成 ad-hoc 包；DR 只有 `cdhash`，每次重建/重装都会变化。
- 用户安装的 `/Applications/MacAppControlDeck.app` 来自 release x86_64 包，因此 TCC 把新包当成另一个应用。

## 目标

1. 本机构建和本地发布包固定使用同一自签名身份。
2. 证书缺失时构建失败，不静默退回 ad-hoc。
3. 构建后自动校验 designated requirement。
4. 把规则写入 `AGENTS.md`，后续 Agent 不得再引入 ad-hoc 本机包。
5. 覆盖安装固定签名版本，避免继续反复授权。

## 实现

- `Build/signing.sh`（新增）
  - 固定身份 `MacAppControlDeck Self-Signed`，SHA-1 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`。
  - `deck_sign_app` 统一签 `KeySender` 和主 App。
  - `deck_assert_stable_signature` 拒绝纯 `cdhash` DR。
  - 只有显式 `DECK_ALLOW_ADHOC=1` 才允许 ad-hoc，并打印权限重置警告。
- `Build/build.sh`
  - 删除原先的多级身份查找和 ad-hoc 回退，改为 source `signing.sh` 后调用 `deck_sign_app`。
- `Build/package-release.sh`
  - 删除固定 ad-hoc 签名，改为默认固定自签名；ad-hoc 需显式允许。
- `Build/verify-signing.sh`（新增）
  - 检查构建产物或已安装 App 的签名、Authority、TeamIdentifier 和 DR；对 ad-hoc 返回非零。
- `README.md`
  - 构建流程改为首次执行 `setup-signing.sh`，再 `build.sh`、`verify-signing.sh`。
  - 发布说明明确本机发布默认固定签名，ad-hoc 是显式例外。
  - 排障条目改为用 `verify-signing.sh` 判断是否装错了 ad-hoc 包。
- `AGENTS.md`
  - 新增 R2：固定签名身份、禁止本机 ad-hoc、禁止修改 Bundle ID/证书/runtime 标志、构建后校验 DR、变更需 OpenSpec。

## 验证

- `zsh -n Build/signing.sh Build/build.sh Build/package-release.sh Build/verify-signing.sh`：通过。
- `./Build/build.sh`：构建成功，日志输出 `==> 签名身份：MacAppControlDeck Self-Signed（flags: --force）`。
- 构建产物 DR：
  `identifier "com.zhaojian.MacAppControlDeck" and certificate root = H"e83574620fe6cf96ba5a9c902f8b6a5c38f5a6b3"`
- 覆盖安装到 `/Applications/MacAppControlDeck.app` 后，`Build/verify-signing.sh` 输出“稳定签名”。
- 对旧 ad-hoc 备份执行 `Build/verify-signing.sh`，正确输出“不稳定签名（ad-hoc，DR 只有 cdhash）”，退出码 1。
- 安装版已重新启动，进程路径为 `/Applications/MacAppControlDeck.app/Contents/MacOS/MacAppControlDeck`。

## 已知限制

- 当前仍使用自签名，不做 Developer ID 和公证；其他机器首次打开仍需右键「打开」。
- 本次覆盖安装后，如果系统设置里只有 ad-hoc 时代的旧条目，可能需要最后重新授权一次；之后固定签名重建不再反复授权。
- 没有修改系统 TCC 数据库，也没有自动执行 `tccutil reset`。

## 用户可见入口

无新增模块或打开入口。本次只改变构建/发布签名流程，按 `AGENTS.md` R0 不需要新增快捷打开按钮。

## 归档

- Docs 记录：`Docs/archive/2026-11-22-stable-code-signing/SUMMARY.md`
- OpenSpec 变更：`openspec/changes/archive/2026-11-22-add-stable-code-signing/`
- 能力规格：`openspec/specs/stable-code-signing/spec.md`
