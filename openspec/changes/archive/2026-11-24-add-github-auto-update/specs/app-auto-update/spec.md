## ADDED Requirements

### Requirement: 自动检查与安装更新
App SHALL 从 GitHub Releases 的 `appcast.xml` 检查新版本，并在下载完成后由用户确认才安装；不得在用户未确认时静默替换正在运行的 App。

#### Scenario: 后台自动检查
- **WHEN** App 启动且「自动检查更新」为开
- **THEN** 按 `SUScheduledCheckInterval`（默认 24 小时）在后台检查 appcast
- **AND** 检查失败（断网、GitHub 不可达）静默忽略，不弹窗、不打断当前操作

#### Scenario: 手动检查
- **WHEN** 用户点击菜单栏「检查更新…」或触发内置操作「检查更新」
- **THEN** 立即检查 appcast；有新版则展示版本号与更新说明
- **AND** 失败时如实提示原因，不谎报「已是最新」

#### Scenario: 安装前确认
- **WHEN** 新版本已下载完成
- **THEN** 提示用户选择「安装并重启」或稍后
- **AND** 未确认时不替换 App；用户选择稍后仍可继续使用旧版

#### Scenario: 版本比较
- **WHEN** appcast 中的 `CFBundleVersion` 不大于当前运行版本
- **THEN** 视为「已是最新」，不提示更新

### Requirement: 更新包安全校验
App SHALL 只接受用内置 EdDSA 公钥（`SUPublicEDKey`）签名且签名身份与当前 App 一致的更新包；校验不通过时拒绝安装并保持当前版本可用。

#### Scenario: 签名不匹配
- **WHEN** 下载到的更新包 EdDSA 签名错误或缺失
- **THEN** 拒绝安装，提示更新包校验失败
- **AND** 当前运行的版本继续正常工作

#### Scenario: 签名身份变化
- **WHEN** 更新包由其他证书签名（Bundle ID 相同但证书不同）
- **THEN** 拒绝升级，避免安装后 TCC 授权全部失效

## MODIFIED Requirements

### Requirement: 更新通道
App SHALL 默认从 `https://github.com/AdrianAndroid/MacAppControlDeck/releases/latest/download/appcast.xml` 获取更新元数据；测试场景允许用 `DECK_UPDATE_FEED` 环境变量覆盖为本地或镜像地址。

#### Scenario: 使用镜像或本地 feed
- **WHEN** 进程环境存在 `DECK_UPDATE_FEED`
- **THEN** 使用该地址代替 `SUFeedURL`，其余校验流程不变
