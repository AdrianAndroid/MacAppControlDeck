# stable-code-signing 变更（add-friendly-installer）

## ADDED Requirements

### Requirement: 接收方临时签名兜底边界

安装脚本 SHALL 仅在接收方机器、且 quarantine 清除后 `codesign --verify` 仍失败时，对已复制的 App 使用本机临时签名（ad-hoc）修复；构建机与发布流程 MUST NOT 因该兜底而降级为 ad-hoc 签名。

#### Scenario: 接收方签名损坏

- **WHEN** 接收方机器上 App 签名校验失败（传输损坏或旧包）
- **THEN** 脚本对 `/Applications/MacAppControlDeck.app` 及其 `KeySender` 执行 `codesign --force --sign -` 修复并再次清除 quarantine
- **AND** 修复只发生在接收方机器，不写回发布包

#### Scenario: 构建机仍禁止降级

- **WHEN** 在构建机上执行 `./Build/build.sh` 或 `./Build/package-release.sh`
- **THEN** 仍然只使用固定身份 `MacAppControlDeck Self-Signed`，找不到证书直接失败
- **AND** 现有 `designated requirement` 校验保持不变
