# 本机发布手册（正式发版机）

2026-11-25 · 这台 Mac 是 MacAppControlDeck 的**正式发版机**。

对应变更：[OpenSpec 提案](../../openspec/changes/archive/2026-11-25-make-local-machine-primary-release-publisher/proposal.md) · [能力规格](../../openspec/specs/local-release-publishing/spec.md) · [v0.4.1 发布说明](v0.4.1.md)

## 1. 为什么改成这台电脑

v0.4.1 最终由本机产物发布，但当时的发版链路不可复现：

- CI 是登记的主路径，实际连续遇到 `macos-14` 镜像退役 → `macos-15` 缺 macOS 26 SDK 的 `SCScreenshot*` API → `macos-26` arm64 runner 排队约 15 分钟，最后只能本机手工拼命令发布。
- 本机 EdDSA 私钥只留在登录钥匙串里。Sparkle 的 `generate_appcast` / `sign_update` 和 `security -w` 非交互读这一项都会弹「允许访问钥匙串」授权框并永久挂起（实测 120 秒无输出被终止）；v0.4.1 发版时用的临时私钥文件已清理，本机因此**无法独立重签 appcast**。
- 本机发版散落在 `package-release.sh`、`make-appcast.sh`、`gh release create` 等多条命令，缺统一自检与线上复核；推 tag 还会触发 CI 抢发。

现在本机具备全部凭据与一条一键链路，不再依赖公司电脑或 CI 容量。

## 2. 凭据清单（都不进仓库）

| 凭据 | 位置 | 作用 |
| --- | --- | --- |
| 固定签名证书 | 登录钥匙串 `MacAppControlDeck Self-Signed` | App 签名 / TCC 授权稳定，SHA-1 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3` |
| EdDSA 私钥（主） | `~/.config/macappcontroldeck/sparkle_ed_key`（600，44 字节 base64 = 32 字节种子） | 本机签 appcast，`--ed-key-file` 读取，非交互 |
| EdDSA 私钥（备份 1） | 登录钥匙串 `Private key for signing Sparkle updates`（acct `ed25519`） | 同一份私钥，`generate_keys -p` 可读公钥 |
| EdDSA 私钥（备份 2） | 仓库 Secret `SPARKLE_ED_PRIVATE_KEY` | 同一份私钥，CI 兜底用 |
| CI 证书 | Secrets `DECK_SIGN_P12_BASE64` / `DECK_SIGN_P12_PASSWORD` | CI 临时钥匙串导入同一张自签名证书 |
| GitHub 登录 | `gh auth status`（账号 `AdrianAndroid`） | 创建 Release / 上传资产 |

**严禁轮换 `SUPublicEDKey`**：v0.4.1 已把公钥内置发布，换密钥会让存量客户端拒绝后续 appcast，自动升级链直接断裂。脚本会用 `generate_keys -p` 断言钥匙串公钥与 `Build/Info.plist` 一致。

### 首次配置 / 换机恢复

```zsh
# 1. 固定签名证书（已有则跳过）
./Build/setup-signing.sh

# 2. Sparkle 工具与二进制产物
swift package resolve

# 3. 从钥匙串导出 EdDSA 私钥到本机（私钥内容不会打印到终端）
mkdir -p ~/.config/macappcontroldeck && chmod 700 ~/.config/macappcontroldeck
./.build/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/.config/macappcontroldeck/sparkle_ed_key
chmod 600 ~/.config/macappcontroldeck/sparkle_ed_key

# 4. GitHub CLI
gh auth login

# 5. 验证本机可独立重签线上 appcast（不改动线上状态）
./Build/publish-local.sh --verify-only
```

> 若换了一台全新的电脑且钥匙串里没有该私钥，只能从备份恢复（钥匙串 / CI Secret 解码出的文件）。**不要**用 `generate_keys` 重新生成密钥对。

## 3. 发布一个版本

```zsh
# 1. 改 Build/Info.plist：CFBundleShortVersionString 与 CFBundleVersion 同时递增
# 2. 写 Docs/releases/<版本>.md（作为 Release 说明），提交并推送 main
git add -A && git commit -m "release(vX.Y.Z): ..." && git push origin main

# 3. 自检：凭据 + 本机重签比对线上 appcast + 产物校验（不改动线上）
./Build/publish-local.sh --verify-only

# 4. 预演：构建 universal + 签 appcast + 全部校验（不推 tag、不发布）
./Build/publish-local.sh --dry-run

# 5. 正式发布（二次确认后自动创建 tag、上传 5 个资产、线上复核）
./Build/publish-local.sh
```

发布完成后脚本会打印 Release 链接与更新源 `https://github.com/AdrianAndroid/MacAppControlDeck/releases/latest/download/appcast.xml`。

### 常用参数

| 参数 | 用途 |
| --- | --- |
| `--verify-only` | 只自检，不构建、不发布；用现有产物重签并比对线上 `edSignature` |
| `--dry-run` | 构建 + 签名 + 校验，不推 tag、不创建 Release |
| `--skip-build` | 复用已有 `BuildOutput/release/universal`（版本必须与 Info.plist 一致） |
| `--yes` | 跳过交互确认（自动化用；非交互终端必须显式加） |
| `--notes-file <path>` | 指定 Release 说明；默认用 `Docs/releases/<版本>.md`，否则 `--generate-notes` |
| `--verify-download` | 发布后再下载更新 ZIP 做 SHA256 复核 |
| `--allow-dirty` | 允许工作区有未提交改动（不建议） |

## 4. 脚本做了什么

1. **凭据自检**：gh 登录与仓库、Sparkle 工具、固定签名证书、私钥 600 权限且解码为 32 字节、钥匙串公钥等于 `SUPublicEDKey`、`SUFeedURL` 指向本仓库。
2. **仓库状态自检**：工作区干净、当前 main、本地 HEAD 等于 `origin/main`、目标 tag 与 Release 都不存在。
3. **构建**：`./Build/package-release.sh universal`（lipo 合并 arm64 + x86_64，固定签名）。
4. **签名**：`make-appcast.sh` 用 `--ed-key-file` 指向本机私钥，非交互生成 `appcast.xml` 与 `SHA256SUMS.txt`。
5. **产物校验**：双架构、`verify-signing.sh`、designated requirement 含当前证书哈希、`shasum -a 256 -c`、appcast 版本/build/下载前缀/`edSignature`，并用 `sign_update` 独立复核签名。
6. **发布**：`gh release create` 上传 5 个资产（自动创建远端 tag 指向 main）。
7. **线上复核**：5 个资产齐全、线上 `appcast.xml` 与 `SHA256SUMS.txt` 与本地逐字节一致；可选下载 ZIP 校验 SHA256。

任何一步失败都会终止，不会创建 Release；已存在的 tag / Release 一律不覆盖。

## 5. CI 的角色

`.github/workflows/release.yml` 现在只是兜底：

- 本机发布创建远端 tag 时也会触发 workflow，但它第一步 `gh release view` 发现 Release 已存在就 `skip=true`，后续全部跳过，不会重复构建或覆盖资产。
- 本机确实没发布成功时，CI 会自动走原有流程补发；也可在 Actions 里手动 `Run workflow` 并填 `tag` 完整补发（不填 tag 则只构建上传 artifact）。

## 6. 故障排查

| 现象 | 处理 |
| --- | --- |
| `generate_appcast` / `sign_update` 卡住不返回 | 说明在弹钥匙串授权框。确认 `~/.config/macappcontroldeck/sparkle_ed_key` 存在且 600；`make-appcast.sh` 已禁止回退钥匙串 |
| 提示私钥不是 32 字节 | 私钥文件被截断或格式错，用 `generate_keys -x` 重新导出 |
| 提示公钥与 `SUPublicEDKey` 不一致 | 不要生成新密钥对；从备份恢复私钥（`generate_keys -f <file>` 导入钥匙串） |
| 提示 tag / Release 已存在 | 本脚本不覆盖，先确认线上状态；必要时手工 `gh release delete` 后再发 |
| 提示本地 HEAD 与 `origin/main` 不一致 | 先 `git pull` / `git push` 同步 |
| 提示证书缺失 | `./Build/setup-signing.sh`；签名身份变了要同步更新 Secrets 与文档指纹 |
| 升级后老版本收不到更新 | 检查 `SUFeedURL`、`appcast.xml` 是否随 Release 上传；确认 `SUPublicEDKey` 未被轮换 |

## 7. 验证记录（2026-11-25）

- 用 `generate_keys -x` 导出本机私钥后，`make-appcast.sh` 对 v0.4.1 更新 ZIP 重签得到的 `edSignature` 与线上 appcast **完全一致**：
  `LAM8lKgT4RrlCk692VQmsmP4K3XtMUpdzWViXixFG3yb760Dvt3KVi4VKyCcuX3RpQMimArQFzPqWsAhgUfWBA==`
- 当前固定证书 SHA-1 `E8357462…` 与 v0.3.1 公司电脑发布包的 designated requirement 一致，升级后 TCC 授权不失配。
- `AGENTS.md` / `README.md` / `Build/signing.sh` / `stable-code-signing` 规格里的过时指纹 `145AEA72…` 已同步为当前值；历史归档文档保留原记录。
