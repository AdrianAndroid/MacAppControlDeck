# 提案：发布 v0.3.1 体积清理版

## Why

v0.3.0 的 GitHub Release 仍包含 35 MB 已弃用的 v5 桌宠图层，安装包约 50.6 MB。源码中 v5 已删除并通过验证，但用户下载到的仍是旧包。

需要一个新版本把实际清理结果交付出去：

- `.app` 从 62 MB 降到约 27 MB。
- DMG 从 50.6 MB 降到约 15 MB。
- 光栅回退链稳定为 `v6 → v4 → 矢量`。
- 不改变桌宠外观、交互、权限或 API。

## What Changes

- `Build/Info.plist`：版本 `0.3.0 / 3` → `0.3.1 / 4`。
- README：当前版本、下载资产名与发布归档更新到 `0.3.1`。
- 新增 `Docs/releases/v0.3.1.md`，写明体积变化、安装、签名、已知限制和校验和。
- 用固定自签名构建 arm64 / x86_64 的 DMG、ZIP 与 `SHA256SUMS.txt`。
- 提交、创建 annotated tag `v0.3.1`、推送 `main` 与 tag。
- 在本机已登录 GitHub 的 Chrome 创建 GitHub Release，上传 5 个资产并设为 Latest。

**非目标**：

- 不改任何桌宠渲染代码、状态机或 UI；本次只交付已验证的 v5 删除结果。
- 不修改签名证书、Bundle ID、DR、权限或发布脚本。
- 不做公证、不接 Sparkle 自动更新。
- 无新增用户可见模块/窗口，按 R0 不需要新增内置打开按钮。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- 无行为变化；`desktop-pet` 规格已在 `remove-legacy-pet-v5-rig` 中更新完毕。

## Impact

- 版本：`Build/Info.plist`。
- 文档：`README.md`、`Docs/releases/v0.3.1.md`。
- 产物：`BuildOutput/release/` 下双架构 DMG/ZIP/SHA256SUMS。
- 远端：Git commit、tag `v0.3.1`、GitHub Release。
- 权限/API/数据：无变化。
- 已知限制：沿用 v0.3.0 的真实 iPhone Safari 未手测、BongoCat 键位高亮未逐键重映射、未公证。
