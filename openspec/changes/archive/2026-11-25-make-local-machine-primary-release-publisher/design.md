# 设计：本机为正式发版机

## 1. 问题定位

本机 v0.4.1 发布后清理了临时私钥文件，只剩登录钥匙串里的 `Private key for signing Sparkle updates`（acct `ed25519`）。该钥匙串项由 Sparkle `generate_keys` 创建，非交互读取会触发 GUI 授权：

| 尝试 | 结果 |
| --- | --- |
| `security find-generic-password -a ed25519 -w` | 15s 无输出，被 SIGALRM 终止 |
| `sign_update <zip>` | 120s 挂起后被终止 |
| `make-appcast.sh`（回退钥匙串） | 120s 挂起后被终止 |
| `generate_keys -p` | 立即返回公钥，无弹窗 |

因此：只要发版流程依赖「从钥匙串直接读私钥」，本机就无法被脚本化。

## 2. 私钥形态（关键决策）

Sparkle `generate_keys -x <file>` 可从钥匙串把私钥导出为 base64 的 32 字节 Ed25519 种子。本机固化方案：

```
~/.config/macappcontroldeck/sparkle_ed_key   (chmod 600, 44 字节 base64)
    ├── 配对的公钥 = Info.plist 的 SUPublicEDKey = x8a3M9og…
    ├── 登录钥匙串 ed25519 项（同一份，备份）
    └── 仓库 Secret SPARKLE_ED_PRIVATE_KEY（同一份，异地备份 / CI 兜底）
```

- `make-appcast.sh` / `publish-local.sh` 一律用 `--ed-key-file` 指向文件，不回退钥匙串，彻底消除弹窗。
- 验证方式：用该文件重签 v0.4.1 更新 ZIP，`generate_appcast` 产出的 `edSignature` 与线上 appcast **完全一致** → 证明本机私钥与已发布公钥配对。
- **禁止轮换公钥**：v0.4.1 已内置 `SUPublicEDKey` 发布，换密钥会让存量客户端拒绝后续 appcast，升级链断裂。

## 3. 发布链路

```
publish-local.sh
  ① check_credentials   gh / Sparkle 工具 / 固定签名证书 / 私钥 600+32B /
                        钥匙串公钥 == SUPublicEDKey / SUFeedURL 指向本仓库
  ② check_repo_state    工作区干净 / main == origin/main / tag 与 Release 不存在
  ③ package-release.sh universal   （arm64 + x86_64，固定签名）
  ④ make-appcast.sh     （--ed-key-file，非交互）
  ⑤ verify_artifacts    架构 / DR 证书哈希 / SHA256SUMS / appcast 版本与前缀 /
                        sign_update 独立复核 edSignature
  ⑥ gh release create   --target main，上传 5 个资产（自动创建远端 tag）
  ⑦ post verify         5 个资产齐全、线上 appcast / SHA256SUMS 与本地逐字节一致
```

`--verify-only` 只跑 ① + 用现有产物重签比对线上签名 + ⑤，不改动任何线上状态；`--dry-run` 跑完 ①～⑤ 不发布。

## 4. CI 降级为兜底

```
push tag v*  →  gate: gh release view 是否已存在？
                 ├─ 是（本机已发布）→ skip=true，后续全部跳过
                 └─ 否 → 原有构建 / 签名 / 发布流程（补发）
workflow_dispatch(inputs.tag) → 指定 tag 完整补发；留空只构建上传 artifact
```

本机 `gh release create` 会创建远端 tag 并触发 workflow，但 CI 排队期间 Release 已存在，gate 必然跳过，不会覆盖本机资产。CI 的三个 Secret 保持不动，作为本机不可用时的异地兜底。

## 5. 指纹同步

当前钥匙串 `MacAppControlDeck Self-Signed` 的 SHA-1 为 `E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`，与 v0.3.1 公司电脑发布包的 designated requirement 一致。`publish-local.sh` 不硬编码指纹比较，而是从证书动态取 SHA-1 后断言产物 DR 含该值，避免证书重建后规则漂移；仅把文档/规格中的静态记录同步为当前值。

## 6. 失败与安全边界

- 任何一步失败即 `exit 1`，不创建 Release；`--verify-only` 与 `--dry-run` 绝不推 tag / 建 Release。
- 检测私钥权限非 600、解码非 32 字节、钥匙串公钥与 `SUPublicEDKey` 不一致时直接拒绝发版。
- 已存在的 tag / Release 一律不覆盖，避免误发重复版本。
- 私钥路径不在仓库内；`.gitignore` 无需改动，脚本错误信息也不打印私钥内容。
