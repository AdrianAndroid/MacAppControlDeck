## MODIFIED Requirements

### Requirement: 固定签名身份
本机与 CI 的所有构建 SHALL 使用同一份固定自签名身份 `MacAppControlDeck Self-Signed` 签名，包括自动升级下发的更新包；证书重建后必须同步到 CI Secrets，任何 ad-hoc 或换证书的更新包不得进入更新通道。

#### Scenario: CI 构建
- **WHEN** GitHub Actions 构建发布包
- **THEN** 从 Secrets 导入固定 `.p12` 到临时钥匙串后签名
- **AND** 签名后断言 designated requirement 含 `certificate root = H"145aea72352c419cccd76d6536bc70e14b2e134f"`
- **AND** 缺失证书时构建失败，不退化为 ad-hoc

#### Scenario: 自动升级
- **WHEN** App 下载更新包
- **THEN** 只有与本机当前 App 同一签名身份的包才允许安装
- **AND** 升级后辅助功能 / 输入监控 / 屏幕录制 / 自动化授权保持有效，无需重新授权
