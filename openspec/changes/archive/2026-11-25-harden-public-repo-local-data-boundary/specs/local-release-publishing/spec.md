# local-release-publishing 变更（harden-public-repo-local-data-boundary）

## ADDED Requirements

### Requirement: 发布链路不得读取或打包本机其他数据

本机发布链路 SHALL 只读取项目专用凭据与项目文件，不得把本机其他数据（个人文件、其他钥匙串条目、其他证书私钥）写入发布产物或提交到 public 仓库。

#### Scenario: 凭据读取范围

- **WHEN** 导出或校验 EdDSA 私钥、代码签名证书
- **THEN** 只操作 Sparkle 的 `ed25519` 项与 `MacAppControlDeck Self-Signed` 证书，不导出其他钥匙串条目或其他身份的私钥
- **AND** 若排查需要枚举钥匙串属性，输出只留在本机终端，不写入文件、不提交、不上传

#### Scenario: 发布产物内容

- **WHEN** 生成 universal ZIP / installer ZIP / DMG 并发布
- **THEN** 产物只包含 App、框架、许可证、图标、安装脚本与说明，不含 `/Users/*` 下的个人文件、`.ssh`、钥匙串或桌面/文档数据
- **AND** 允许存在 SwiftPM 编译进二进制的项目构建路径字符串（不含文件内容）

### Requirement: 凭据文件不得进入仓库

本机 EdDSA 私钥 SHALL 存放在仓库外（600 权限），仓库 SHALL 忽略常见凭据文件格式，发布脚本 MUST 在自检阶段断言私钥未被 git 跟踪。

#### Scenario: 发布前自检

- **WHEN** 执行 `./Build/publish-local.sh`
- **THEN** 若私钥文件位于仓库目录内或已被 `git ls-files` 跟踪，直接失败
- **AND** 私钥权限非 600 或解码非 32 字节时同样失败

#### Scenario: 防误提交

- **WHEN** 本机出现 `*.p12` / `*.pem` / `*.key` / `sparkle_ed_key` / `weather-secrets.json` / `.env*` 等文件
- **THEN** `.gitignore` 阻止其被 `git add` 追踪
- **AND** 任何新增忽略规则不得影响已有已跟踪文件
