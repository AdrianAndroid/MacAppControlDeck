# stable-code-signing Specification

## Purpose

定义本机构建、发布打包与签名校验的固定身份规则，确保辅助功能、输入监控、屏幕录制和自动化授权跨重建保持匹配，避免反复授权。

## Requirements

### Requirement: 本机构建使用固定签名身份

本机开发与本机发布构建 SHALL 使用固定签名身份 `MacAppControlDeck Self-Signed`，不得在身份缺失时静默降级为 ad-hoc。当前证书 SHA-1 指纹记录于此（`145AEA72352C419CCCD76D6536BC70E14B2E134F`）；证书被重建或重新信任后指纹会变化，此时 MUST 同步更新本规格与 `Build/signing.sh`，并知悉 TCC 授权需要按新身份重新授予一次。

#### Scenario: 正常构建

- **WHEN** 开发者执行 `./Build/build.sh`
- **THEN** 构建日志显示 `==> 签名身份：MacAppControlDeck Self-Signed`
- **AND** `codesign -d --requirements -` 的 designated requirement 包含 `identifier "com.zhaojian.MacAppControlDeck"` 和 `certificate root = H"145aea72352c419cccd76d6536bc70e14b2e134f"`
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

### Requirement: TCC 授权范围

以下授权 SHALL 通过固定签名身份保持匹配，不按 Bundle ID 无条件继承：

- 辅助功能：跨桌面激活、Event Tap 等
- 输入监控：桌宠/快捷键读取物理按键
- 屏幕录制：截图、录屏
- 自动化：通过 System Events 切换桌面

#### Scenario: 重建后授权仍有效

- **WHEN** 使用固定签名身份重新构建并覆盖安装
- **THEN** 上述权限不需要重新授予
- **AND** 若系统设置中存在旧签名条目，只删除旧条目并重新添加当前 App，不使用 `tccutil reset` 批量清空

### Requirement: 接收方临时签名兜底边界

安装脚本 SHALL 仅在接收方机器、且 quarantine 清除后 `codesign --verify` 仍失败时，对已复制的 App 使用本机临时签名（ad-hoc）修复；构建机与发布流程 MUST NOT 因该兜底而降级为 ad-hoc 签名。

#### Scenario: 接收方签名损坏

- **WHEN** 接收方机器上 App 签名校验失败（传输损坏或旧包）
- **THEN** 脚本对 `/Applications/MacAppControlDeck.app` 及其 `KeySender` 执行 `codesign --force --sign -` 修复并再次清除 quarantine
- **AND** 修复只发生在接收方机器，不写回发布包

#### Scenario: 构建机仍禁止降级

- **WHEN** 在构建机上执行 `./Build/build.sh` 或 `./Build/package-release.sh`
- **THEN** 仍然只使用固定身份 `MacAppControlDeck Self-Signed`，找不到证书直接失败
- **AND** 现有 designated requirement 校验保持不变
