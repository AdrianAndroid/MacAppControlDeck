# Change: 从 GitHub Releases 自动升级

## Why

现在每次升级都要手动下载 DMG/ZIP、右键打开、拖进应用程序目录，还要重新授权（ad-hoc 包）或确认版本。用户明确要求「新的安装版本全部从 GitHub 上获取」，即首次手动安装一次之后，后续新版由 App 自己从 GitHub Releases 拉取并安装。

本项目的分发包是自签名（无 Apple 开发者证书、不公证），所以不能依赖系统信任链校验更新包；必须自带公钥校验，并继续使用同一份自签名证书签名，否则 TCC 授权（辅助功能 / 输入监控 / 屏幕录制 / 自动化）会全部失效。

## What Changes

1. 引入 Sparkle 2（SPM binary target），`Info.plist` 写入 `SUFeedURL`（GitHub Releases latest 的 `appcast.xml`）与 `SUPublicEDKey`；所有更新包用 EdDSA 私钥签名，App 内置公钥校验。
2. 新增 updater 本体（`Sources/MacAppControlDeck/Updater/`）：
   - 启动即按 `SUScheduledCheckInterval` 后台检查（默认 24h），下载完成后提示「重启以完成更新」，由用户确认才安装；
   - 菜单栏一级入口「检查更新…」，设置 →「通用」增加「自动检查更新」开关与上次检查结果；
   - 内置操作 `update.check`（「检查更新」），可从按钮管理添加，同时出现在菜单栏快捷操作与手机面板（R0）。
3. 打包改为 **universal 单包**：`Build/package-release.sh universal` 用 `--arch arm64` + `--arch x86_64` 分别构建后 `lipo` 合并，appcast 只有一条记录，避免下错架构。
4. `Build/build.sh` / `package-release.sh` 统一嵌入 `Sparkle.framework`（`Contents/Frameworks`）、补齐 `@executable_path/../Frameworks` rpath，并对嵌套代码签名。
5. 新增 `Build/make-appcast.sh`：用 Sparkle 官方 `generate_appcast` 为 ZIP 生成 `appcast.xml`，同时产出 `SHA256SUMS.txt`。
6. 新增 GitHub Actions 工作流 `.github/workflows/release.yml`：推送 `v*` 标签（或手动触发）时在 macOS runner 上导入固定自签名 `.p12`、构建 universal 包、签名、生成 appcast、发布 Release 附件。
7. 更新源可覆盖：debug 场景可用 `DECK_UPDATE_FEED` 环境变量指向本地 appcast，便于真机验证升级链路。

## Capabilities

- `app-auto-update`（新增）：检查 / 下载 / 安装 GitHub Releases 上的新版本，EdDSA 校验，用户确认后重启。
- `stable-code-signing`（修改）：更新包必须与原包使用同一签名身份，否则拒绝升级。

## Impact

- 新增依赖：`Sparkle 2.10.1`（SPM 二进制 target，约 3 MB）。
- 新增 Secrets：`DECK_SIGN_P12_BASE64`、`DECK_SIGN_P12_PASSWORD`、`SPARKLE_ED_PRIVATE_KEY`。
- 首次安装仍需手动（浏览器下载的包会被 Gatekeeper 拦），更新由 App 内部网络请求下载，不再经过浏览器。
- 版本号规则：`CFBundleShortVersionString` 递增，`CFBundleVersion`（build number）必须单调递增，否则 Sparkle 认为没有新版。
- 用户数据目录不变，升级后按钮、配对、快捷键、桌宠设置全部保留。
- 需要重新构建并覆盖安装一次才能进入自动升级通道。

## Non-goals

- 不做增量（delta）更新，每次下完整 universal ZIP。
- 不接入 Apple 公证 / Developer ID；首次安装仍需「右键打开」。
- 不做多通道（beta/stable）发布，只有 GitHub latest。
- 不做静默强制安装：安装前必须由用户确认重启。
