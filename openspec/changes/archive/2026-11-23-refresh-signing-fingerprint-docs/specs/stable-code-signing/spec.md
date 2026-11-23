# stable-code-signing 变更（refresh-signing-fingerprint-docs）

## MODIFIED Requirements

### Requirement: 本机构建使用固定签名身份

本机开发与本机发布构建 SHALL 使用固定签名身份 `MacAppControlDeck Self-Signed`，不得在身份缺失时静默降级为 ad-hoc。当前证书的 SHA-1 指纹 SHALL 记录在本文档与 `Build/signing.sh` 中；证书被重建或重新信任后指纹会变化，此时 MUST 同步更新记录。

#### Scenario: 正常构建

- **WHEN** 开发者执行 `./Build/build.sh`
- **THEN** 构建日志显示 `==> 签名身份：MacAppControlDeck Self-Signed`
- **AND** designated requirement 包含 `identifier "com.zhaojian.MacAppControlDeck"` 和 `certificate root = H"145aea72352c419cccd76d6536bc70e14b2e134f"`
- **AND** 不包含仅以 `cdhash` 作为 DR 的签名

#### Scenario: 证书重建后的授权

- **WHEN** 固定证书被重新创建或重新信任，指纹发生改变
- **THEN** 用新指纹重新构建并覆盖安装后，系统把应用视为新签名身份
- **AND** 辅助功能、输入监控、屏幕录制与自动化授权需要人工重新授予一次，之后同一指纹重建不再反复失效
