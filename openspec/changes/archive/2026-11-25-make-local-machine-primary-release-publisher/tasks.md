# Tasks

- [x] 定位本机发版阻塞：确认钥匙串 ed25519 项存在但非交互读取会弹授权框挂起
- [x] 用 `generate_keys -x` 导出私钥到 `~/.config/macappcontroldeck/sparkle_ed_key`（600 权限）
- [x] 验证导出私钥重签 v0.4.1 appcast 的 edSignature 与线上完全一致
- [x] 新增 `Build/publish-local.sh`：凭据自检 / 仓库状态自检 / 构建 / 签名 / 产物校验 / 发布 / 线上复核
- [x] 支持 `--verify-only`、`--dry-run`、`--skip-build`、`--yes`、`--verify-download`、`--notes-file`
- [x] `Build/make-appcast.sh` 私钥优先级改为文件优先，移除钥匙串回退与无用 `swift build --show-bin-path`
- [x] `.github/workflows/release.yml` 增加幂等 gate 与 `workflow_dispatch` tag 输入，CI 降级为兜底
- [x] 同步当前证书指纹 `E8357462…` 到 `AGENTS.md`、`README.md`、`Build/signing.sh` 与 `stable-code-signing` 主规格
- [x] 重写 README 发版章节，新增 `Docs/releases/local-publish.md` SOP，补充 v0.4.1 发布记录与反向链接
- [x] `publish-local.sh --verify-only` 端到端自检通过、`zsh -n` 语法检查、全量脚本复核
- [x] 归档变更并同步 `openspec/specs/` 主规格
