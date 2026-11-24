# Change: 把本机设为正式发版机（本机一键发布）

## Why

用户明确「重点发布还是要在这台电脑上，这是我自己的电脑」。v0.4.1 最终由本机产物发布，但发版链路不可复现，本机不具备稳定的独立发版能力：

1. README 登记的主发版路径是 CI，实际受 runner 镜像退役（`macos-14`）、macOS 26 SDK 需求（`macos-26`）、arm64 runner 容量排队约 15 分钟影响，最后只能本机手工拼命令发版。
2. 本机 EdDSA 私钥只存在于登录钥匙串。`generate_appcast` / `sign_update` / `security -w` 非交互读取该钥匙串项会弹「允许访问钥匙串」授权框并永久挂起（实测 120s 无输出被终止）；v0.4.1 发版时用的临时私钥文件已清理，本机因此无法独立重签 appcast。
3. 本机发版步骤散落在 `package-release.sh`、`make-appcast.sh`、`gh release create` 等多条命令，缺统一入口、前置自检与线上复核；推 tag 还会触发 CI 抢发。
4. `AGENTS.md` / `README.md` / `Build/signing.sh` / `stable-code-signing` 主规格仍记录过时证书指纹 `145AEA72…`，与当前 `E8357462…` 不符。

## What Changes

1. 新增 `Build/publish-local.sh`：本机一键发布（凭据自检 → 构建 universal → 本机私钥签 appcast → 产物校验 → 创建 Release → 线上复核），支持 `--verify-only` / `--dry-run` / `--skip-build` / `--yes` / `--verify-download`；发布前要求工作区干净、main 与 `origin/main` 同步、tag 与 Release 均不存在。
2. `Build/make-appcast.sh`：私钥优先级改为 CI Secret 文件 → 本机固化文件，删除会弹授权框的钥匙串回退和无用的 `swift build --show-bin-path`。
3. 用 Sparkle 官方 `generate_keys -x` 把私钥从钥匙串导出到本机 `~/.config/macappcontroldeck/sparkle_ed_key`（600 权限，不进仓库、不打印内容）；与 `SUPublicEDKey` 严格配对，**不轮换公钥**，保证 v0.4.1 存量用户升级链不断。
4. `.github/workflows/release.yml`：CI 降级为兜底；push tag 触发时若 Release 已由本机发布则整体跳过（幂等，不重复构建、不覆盖资产）；`workflow_dispatch` 支持输入 tag 完整补发。
5. 当前证书指纹 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3` 同步到 `AGENTS.md` R2、`README.md`、`Build/signing.sh` 与 `stable-code-signing` 主规格。
6. 文档：新增 `Docs/releases/local-publish.md` 本机发布 SOP，重写 README 发版章节，补充 v0.4.1 发布记录。

## Capabilities

### New Capabilities

- `local-release-publishing`：本机一键发布链路、凭据约束、CI 兜底幂等。

### Modified Capabilities

- `stable-code-signing`：证书指纹记录更新为当前证书，新增本机发版机与 CI 兜底的签名身份约束。

## Impact

- 代码范围：仅 `Build/` 脚本、`.github/workflows/release.yml`、文档与规格；App 源码与单元测试不变。**无用户可见入口**（纯发布工程变更，按 AGENTS R0 在提交说明中写明）。
- 安全：私钥只在本机用户目录以 600 权限保存，不进仓库、脚本不打印其内容；CI Secret 与登录钥匙串仍作为同一份私钥的备份。
- 兼容性：不轮换 `SUPublicEDKey`，v0.4.1 起所有已安装 App 的 Sparkle 校验链保持有效。
- 运维：正式发版不再依赖公司 Mac 或 CI runner 容量；本机发布后 CI 自动跳过，避免双发。

## 非目标

- 不引入 Apple 公证 / Developer ID 签名。
- 不改变 Sparkle 更新包格式（仍为完整 universal ZIP，不做增量）。
- 不改写历史归档文档中的旧指纹（保留为当时事实）。
