# stable-code-signing 规格 delta

## ADDED Requirements

### Requirement: 本机构建使用固定签名身份

本机开发与本机发布构建 SHALL 使用固定签名身份 `MacAppControlDeck Self-Signed`（SHA-1 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`），不得在身份缺失时静默降级为 ad-hoc。

#### Scenario: 正常构建

- **WHEN** 开发者执行 `./Build/build.sh`
- **THEN** 构建日志显示 `已使用签名身份：MacAppControlDeck Self-Signed`
- **AND** `codesign -d --requirements -` 的 designated requirement 包含 `identifier "com.zhaojian.MacAppControlDeck"` 和 `certificate root = H"e83574620fe6cf96ba5a9c902f8b6a5c38f5a6b3"`
- **AND** 不包含仅以 `cdhash` 作为 DR 的签名

#### Scenario: 证书缺失

- **WHEN** 钥匙串中找不到固定签名身份
- **THEN** 构建失败并提示执行 `./Build/setup-signing.sh`
- **AND** 不得自动生成 ad-hoc 包并继续完成构建

### Requirement: 本地发布包保持同一签名

`Build/package-release.sh` SHALL 默认使用与本机构建相同的固定签名身份。ad-hoc 仅允许在显式设置 `DECK_ALLOW_ADHOC=1` 时使用，并必须提示该包会重置 TCC 授权。

#### Scenario: 本机生成发布包

- **WHEN** 开发者在本机执行 `./Build/package-release.sh arm64` 或 `x86_64`
- **THEN** App、ZIP、DMG 内的主程序使用 `MacAppControlDeck Self-Signed`
- **AND** 重新安装同版本或后续版本时，TCC 授权仍匹配同一 certificate root

#### Scenario: CI 无证书

- **WHEN** 构建机没有固定签名身份且显式设置 `DECK_ALLOW_ADHOC=1`
- **THEN** 允许生成 ad-hoc 包
- **AND** 日志必须说明该包每次重建都会重置 TCC 授权
- **AND** 该包不得作为本机日常使用包安装

### Requirement: 签名可验证

仓库 SHALL 提供 `Build/verify-signing.sh`，用于检查构建产物或已安装 App 的签名身份与 designated requirement。

#### Scenario: 检查已安装 App

- **WHEN** 执行 `./Build/verify-signing.sh /Applications/MacAppControlDeck.app`
- **THEN** 输出 `Authority`、`TeamIdentifier` 和 designated requirement
- **AND** 对 ad-hoc 或仅 `cdhash` 的 DR 返回非零退出码
- **AND** 对固定自签名身份返回成功

### Requirement: 权限规则进入项目规则

`AGENTS.md` SHALL 包含固定签名与 TCC 授权规则，明确禁止本机使用 ad-hoc 签名、禁止修改 Bundle ID/签名证书/签名标志，并要求每次构建后校验 DR。

#### Scenario: 后续开发

- **WHEN** 后续 Agent 修改构建、打包或签名流程
- **THEN** 必须先阅读并遵守 `AGENTS.md` 的稳定签名规则
- **AND** 任何签名流程变更必须有 OpenSpec 变更记录
