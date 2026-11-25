# Change: 固化 public 仓库的本地数据边界

## Why

用户澄清担心点不是软件私钥（练手项目不怕泄漏），而是「会不会把这台电脑上其他本地数据泄漏到 public 仓库」。上一轮为本机发版导出了 Sparkle 私钥、读取过钥匙串与证书，需要给出可复核的边界证据，并防止未来误把本机凭据 / 个人数据提交进仓库。

## What Changes

1. `.gitignore` 增加通用忽略规则：`*.p12` / `*.pfx` / `*.pem` / `*.p8` / `*.key` / `*.mobileprovision`、`sparkle_ed_key`、`weather-secrets.json`、`.env*`；已确认不影响任何已跟踪文件。
2. `Build/publish-local.sh` 凭据自检新增断言：私钥文件不得位于仓库目录内、不得被 git 跟踪。
3. `Docs/releases/local-publish.md` 新增「public 仓库的本地数据边界」章节：全量 git 对象扫描（3340 个，私钥 0 命中）、发布包内容核查、GitHub 安全设置与 workflow 触发条件、操作范围说明、commit 作者邮箱提醒与自查命令。
4. `local-release-publishing` 能力新增「发布链路不得读取或打包本机其他数据」与「凭据文件不得进入仓库」要求。

## Capabilities

### Modified Capabilities

- `local-release-publishing`：新增本地数据边界要求。

## Impact

- 范围：仅 `.gitignore`、发布脚本自检、文档与规格；App 行为不变。**无用户可见入口**（纯发布工程文档/防护变更，AGENTS R0）。
- 不改 git 历史、不改 GitHub 仓库设置（secret scanning 与 push protection 已启用）、不删除 `/tmp` 残留（只读报告，由用户决定）。
- 结论：核查未发现本机其他数据进入仓库或发布包；历史 commit 作者邮箱属于 public 仓库既有元信息，非本次造成。

## 非目标

- 不重写 git 历史以抹除已公开的作者邮箱。
- 不清理本机临时文件、不改动钥匙串内容。
- 不调整 CI 触发方式（现有 workflow 不响应 PR，fork 无法取 Secrets）。
