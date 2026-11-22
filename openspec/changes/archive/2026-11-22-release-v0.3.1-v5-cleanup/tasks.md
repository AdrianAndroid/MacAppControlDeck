# 任务清单：release-v0.3.1-v5-cleanup

## 1. 版本与文档

- [x] 1.1 `Build/Info.plist` 改为 `0.3.1 / 4`
- [x] 1.2 README 当前版本与下载资产名改为 `0.3.1`
- [x] 1.3 新增 `Docs/releases/v0.3.1.md`
- [x] 1.4 README 发布归档新增 `v0.3.1`

## 2. 构建

- [x] 2.1 `./Build/package-release.sh arm64`
- [x] 2.2 `./Build/package-release.sh x86_64`
- [x] 2.3 合并双架构 ZIP/DMG/SHA256SUMS 到 `BuildOutput/release/`
- [x] 2.4 校验四个产物的 sha256、架构与固定签名

## 3. 提交与发布

- [x] 3.1 只暂存本次发布相关文件并提交
- [x] 3.2 创建 annotated tag `v0.3.1`
- [x] 3.3 推送 `main` 与 tag
- [x] 3.4 在本机 Chrome 创建 GitHub Release，上传 5 个资产
- [x] 3.5 GitHub API 核对 tag、Latest、资产名称与大小

## 4. 归档

- [x] 4.1 变更移入 `openspec/changes/archive/2026-11-22-release-v0.3.1-v5-cleanup/`
