# stable-code-signing 变更（make-local-machine-primary-release-publisher）

## MODIFIED Requirements

### Requirement: 本机构建使用固定签名身份

本机开发与本机发布构建 SHALL 使用固定签名身份 `MacAppControlDeck Self-Signed`，不得在身份缺失时静默降级为 ad-hoc。当前证书 SHA-1 指纹记录于此（`E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`，2026-11-25 核对与公司电脑发布的 v0.3.1 一致）；证书被重建或重新信任后指纹会变化，此时 MUST 同步更新本规格与 `Build/signing.sh`，并知悉 TCC 授权需要按新身份重新授予一次。

#### Scenario: 正常构建

- **WHEN** 开发者执行 `./Build/build.sh`
- **THEN** 构建日志显示 `==> 签名身份：MacAppControlDeck Self-Signed`
- **AND** `codesign -d --requirements -` 的 designated requirement 包含 `identifier "com.zhaojian.MacAppControlDeck"` 和 `certificate root = H"e83574620fe6cf96ba5a9c902f8b6a5c38f5a6b3"`
- **AND** 不包含仅以 `cdhash` 作为 DR 的签名

#### Scenario: 证书缺失

- **WHEN** 钥匙串中找不到固定签名身份
- **THEN** 构建失败并提示执行 `./Build/setup-signing.sh`
- **AND** 不得自动生成 ad-hoc 包并继续完成构建

## ADDED Requirements

### Requirement: 本机发版机与 CI 兜底使用同一签名身份

`Build/publish-local.sh`（正式发版机）与 `.github/workflows/release.yml`（兜底补发）SHALL 使用同一份固定自签名身份；本机发布脚本 MUST 在发布前从钥匙串动态读取当前证书 SHA-1，并断言产物 designated requirement 含该哈希，不得硬编码历史指纹。

#### Scenario: 本机发布

- **WHEN** 执行 `./Build/publish-local.sh` 构建并校验发布包
- **THEN** 产物通过 `verify-signing.sh`，且 DR 的 certificate root 哈希等于当前证书 SHA-1 的小写形式
- **AND** CI 检测到该 Release 已存在时跳过，不重复构建或覆盖资产

#### Scenario: CI 补发

- **WHEN** 本机未发布、CI 兜底构建发布包
- **THEN** runner 从 `DECK_SIGN_P12_BASE64` 导入同一证书后签名，DR 仍为当前固定证书
- **AND** `SUPublicEDKey` 保持不变，自动升级链不断裂
