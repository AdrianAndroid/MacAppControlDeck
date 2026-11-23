# 提案：更新签名身份指纹与归档记录

## Why

本机重新安装 App 时发现钥匙串里已没有原固定证书（`E8357462…`），只剩私钥完好的 `MacAppControlDeck Self-Signed`，但其信任设置丢失（`CSSMERR_TP_NOT_TRUSTED`）。

处理方式：把该证书重新设为「代码签名」信任后继续使用，得到新的 designated requirement `certificate root = H"145aea72…"`。旧指纹写在 `AGENTS.md`、`README.md`、`Build/signing.sh` 与能力规格里，已经和现实不符，继续保留会误导排查。

同时本轮还改动了手机面板与发布流程（横屏时钟、双击安装脚本、设置页深链接、聊天传输 ZIP），需要一份可回溯的归档记录。

## What Changes

- `Build/signing.sh` 的 `DECK_CANONICAL_SIGN_SHA1` 更新为当前证书 `145AEA72352C419CCCD76D6536BC70E14B2E134F`。
- `AGENTS.md` R2 与 `README.md` 的固定身份说明改为「身份名称固定，指纹以当前证书为准」，并记录本次变更。
- `openspec/specs/stable-code-signing/spec.md` 的指纹同步更新，补充「证书被重建/重信任时指纹会变化，旧 TCC 授权需重新授予一次」的说明。
- 新增 `Docs/archive/2026-11-23-friendly-install-and-panel-clock/SUMMARY.md`，汇总本轮全部改动与验证结论，并反向链接各 OpenSpec 变更。

**非目标**：

- 不更换 Bundle ID，不改签名流程与参数（仍不加 hardened runtime、仍禁止构建机降级 ad-hoc）。
- 不改历史发布说明 `Docs/releases/v0.3.0.md` / `v0.3.1.md` 中当时的指纹，保持历史准确。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `stable-code-signing`：固定身份的指纹更新，并说明重建证书对 TCC 授权的影响。

## Impact

- 文档：`AGENTS.md`、`README.md`、`openSpec/specs/stable-code-signing/spec.md`、`Docs/archive/2026-11-23-friendly-install-and-panel-clock/SUMMARY.md`。
- 脚本：`Build/signing.sh` 常量（仅注释性常量，不参与校验逻辑）。
- 权限：本机已用新指纹重新构建并覆盖安装，TCC 授权需按新身份重新授予一次。
