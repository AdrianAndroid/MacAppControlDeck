# Tasks

- [x] 建变更记录与能力 delta
- [x] 新增 `FullDiskAccessGate`（整块占位 + 授权入口）
- [x] 概览 / 清理 / 大文件 / 重复文件：未授权整块替换，去掉不完整横幅
- [x] 应用卸载：残留区替换为占位，禁用「扫描残留」
- [x] `swift build` 通过
- [x] 构建 + 固定签名覆盖安装
- [x] 同步 `openspec/specs/system-cleaner/spec.md` 并归档

## Verification

- `swift build` 通过
- 本机当前已有 FDA，占位效果需临时关闭「完全磁盘访问」后打开 PureMac 复核
