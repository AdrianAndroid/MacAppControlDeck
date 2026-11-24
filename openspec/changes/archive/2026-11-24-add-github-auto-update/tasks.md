# Tasks

- [x] 建变更记录、设计与能力 delta
- [x] `Package.swift` 引入 Sparkle 2.10.1 并确认 `swift build` 通过
- [x] `Build/Info.plist` 写入 `SUFeedURL` / `SUPublicEDKey` / `SUScheduledCheckInterval` / `SUAutomaticallyUpdate=false`
- [x] 生成 EdDSA 密钥对，公钥入 Info.plist，私钥导出为 Secrets 用文本
- [x] 实现 `Updater/UpdateController.swift`（Sparkle 封装 + `DECK_UPDATE_FEED` 覆盖 + 自动检查开关）
- [x] 菜单栏「检查更新…」+ 设置 → 通用「自动检查更新」开关与状态
- [x] `BuiltinActions` 注册 `update.check`「检查更新」，接菜单栏与手机面板
- [x] 构建脚本嵌入 `Sparkle.framework`、补 rpath、按序签名
- [x] `package-release.sh` 新增 `universal`（lipo 合并 + 架构断言）
- [x] `Build/make-appcast.sh`（generate_appcast + SHA256SUMS）
- [x] 本机端到端验证：feed 指向本地 appcast，从 +4 升到 +5，TCC 保持
- [x] `.github/workflows/release.yml`：tag/手动触发、导入 p12、构建签署、发布 Release
- [x] 配置 3 个 Secrets（证书 p12、密码、EdDSA 私钥）
- [x] 构建 + 固定签名覆盖安装，README/spec 更新并归档

## Verification

- 本机端到端：`0.4.0(5)` → `0.4.1(6)` 通过本地 appcast 真实升级并重启，签名身份不变
- `./Build/package-release.sh universal` → `x86_64 arm64`，ZIP 19MB / DMG 21MB
- 自签名宿主 + 自签名更新包通过 Sparkle 的签名校验（无 improperly signed）
- CI 与 Secrets 尚未跑通（等待 GitHub Secrets 配置）
