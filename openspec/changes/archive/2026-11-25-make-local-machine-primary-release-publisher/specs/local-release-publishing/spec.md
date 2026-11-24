# local-release-publishing 变更（make-local-machine-primary-release-publisher）

## ADDED Requirements

### Requirement: 本机一键发布为主发版路径

本机 SHALL 提供 `Build/publish-local.sh` 作为正式发版命令，一条命令完成凭据自检、universal 构建、EdDSA appcast 签名、产物校验、GitHub Release 创建与线上复核；不得要求发版人手工拼接多条命令，也不得依赖公司电脑或 CI runner 容量。

#### Scenario: 正式发布

- **WHEN** 开发者在 main 分支执行 `./Build/publish-local.sh`
- **THEN** 脚本依次执行凭据自检、构建 `./Build/package-release.sh universal`、用本机私钥生成 appcast、产物校验，再以 `gh release create` 创建 Release 并上传 5 个资产（universal.zip / installer.zip / dmg / appcast.xml / SHA256SUMS.txt）
- **AND** 发布后复核线上资产齐全、`appcast.xml` 与 `SHA256SUMS.txt` 与本地逐字节一致
- **AND** 输出 Release 链接与 Sparkle 更新源地址

#### Scenario: 自检与预演

- **WHEN** 执行 `./Build/publish-local.sh --verify-only` 或 `--dry-run`
- **THEN** 不推送 tag、不创建 Release、不改变任何线上状态
- **AND** `--verify-only` 用现有产物重签 appcast，确认 `edSignature` 与线上 appcast 完全一致，以此证明本机具备独立发版能力
- **AND** `--dry-run` 完成构建、签名与全部产物校验后停止

### Requirement: EdDSA 私钥固化且禁止轮换公钥

本机 SHALL 使用 Sparkle 官方工具从登录钥匙串导出的私钥文件（`~/.config/macappcontroldeck/sparkle_ed_key`，600 权限、32 字节 Ed25519 种子、不进仓库），并且 MUST NOT 轮换 `Build/Info.plist` 的 `SUPublicEDKey`。

#### Scenario: 私钥可用

- **WHEN** 发布脚本或 `make-appcast.sh` 需要签名
- **THEN** 以 `--ed-key-file` 指向私钥文件（CI 优先用 Secret 解码出的临时文件），不得回退到会弹授权框的钥匙串读取
- **AND** 私钥文件权限非 600、解码非 32 字节时直接失败

#### Scenario: 公钥一致性

- **WHEN** 凭据自检
- **THEN** 用 `generate_keys -p` 读取钥匙串公钥，断言与 `SUPublicEDKey` 一致
- **AND** 用 `sign_update` 以该私钥独立复核 appcast 的 `edSignature`
- **AND** 不一致时拒绝发版，禁止生成新密钥对（否则 v0.4.1 存量用户的 Sparkle 升级链断裂）

### Requirement: CI 降级为幂等兜底

`.github/workflows/release.yml` SHALL 仅作为本机发布失败时的补发路径，不得与本机发布重复构建或覆盖已发布资产。

#### Scenario: 本机已发布

- **WHEN** 推送 `v*` 标签触发 workflow，且 `gh release view` 显示该 Release 已存在
- **THEN** 设置 `skip=true`，跳过导入证书、构建、签名、上传 artifact 与发布 Release 全部步骤
- **AND** 不覆盖任何已上传资产

#### Scenario: CI 补发

- **WHEN** Release 不存在（本机未发布），或手动 `workflow_dispatch` 并指定 tag
- **THEN** CI 沿用原有固定签名身份与仓库 Secret 完成构建、签名、校验与发布
- **AND** 标签版本与 `Build/Info.plist` 的 `CFBundleShortVersionString` 一致

### Requirement: 发布前仓库状态与防重复

发布脚本 SHALL 在改动线上状态前断言仓库状态，已存在的 tag / Release 一律不覆盖。

#### Scenario: 状态不满足

- **WHEN** 工作区有未提交改动、当前分支不是 main、本地 HEAD 与 `origin/main` 不一致
- **THEN** 直接失败并给出可执行的修复提示，不创建 Release

#### Scenario: 版本已发布

- **WHEN** 本地 tag 或远程 Release 已存在
- **THEN** 直接失败，不覆盖已有 Release
- **AND** 产物 App 的 `CFBundleShortVersionString` 与 `Build/Info.plist` 不一致时（如 `--skip-build` 跨版本复用）同样失败

### Requirement: 产物发布前校验

发布脚本 SHALL 在创建 Release 前校验全部产物，任一校验失败即终止。

#### Scenario: 校验项

- **WHEN** 产物已构建并完成 appcast 签名
- **THEN** 校验 universal 架构含 arm64 与 x86_64、`verify-signing.sh` 通过、designated requirement 含当前固定证书哈希、`shasum -a 256 -c SHA256SUMS.txt` 通过
- **AND** 校验 appcast 含 `edSignature`、版本与 build 号、下载前缀指向 `releases/download/v<版本>/`
- **AND** 用 `sign_update` 独立复核 `edSignature` 一致
