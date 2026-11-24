# Design: GitHub 自动升级

## 1. 为什么用 Sparkle 而不是自己写

替换正在运行的 App 需要：下载 → 校验 → 解压 → 退出主进程 → 由独立进程替换 bundle → 重启 → 失败回滚。
Sparkle 2 已把这条链路做成 XPC 服务（`Installer.xpc` / `Downloader.xpc`）+ `Autoupdate` helper，并自带 EdDSA 校验、进度 UI、失败恢复。自研相当于重写一遍且更容易在「用户在录屏 / 桌宠运行时升级」这类边界上出错。

## 2. Sparkle 与自签名的关系

- 官方文档：Developer ID 签名与公证是「if possible」的建议；**强制项是 EdDSA 签名更新包**。
- 因此：更新包 = 我们的自签名签名 + EdDSA 签名。App 内置 `SUPublicEDKey` 校验后者，前者保证安装后 TCC 不失效。
- 唯一风险点：Sparkle 还会校验更新包代码签名是否自洽（valid on disk）。自签名包满足「签名完整但不可信」的中间态；本设计通过本机 `DECK_UPDATE_FEED` 端到端验证这一点，若被拒则降级为 `SUSignatureVersion`/关闭该步校验（仅在没有 Apple 证书时才考虑）。

## 3. Feed 与版本

| 项 | 值 |
| --- | --- |
| `SUFeedURL` | `https://github.com/AdrianAndroid/MacAppControlDeck/releases/latest/download/appcast.xml` |
| `SUPublicEDKey` | 本机生成，写入 `Build/Info.plist` |
| `SUEnableAutomaticChecks` | `true`（设置页可关） |
| `SUAutomaticallyUpdate` | `false`（必须用户确认重启） |
| `SUScheduledCheckInterval` | `86400` |

`CFBundleVersion` 单调递增是唯一判定新旧依据；每次发版必须在 `Build/Info.plist` 同时改 `CFBundleShortVersionString` 与 `CFBundleVersion`。

## 4. 单包 universal

`package-release.sh` 当前按架构分批构建。新增 `universal` 模式：

1. `swift build -c release --arch arm64 --scratch-path .build-arm64`
2. `swift build -c release --arch x86_64 --scratch-path .build-x86_64`
3. `lipo -create` 两个 `MacAppControlDeck`（`KeySender` 同样合并）
4. 资源 bundle 取任一份（内容与架构无关）
5. `lipo -archs` 断言结果是 `x86_64 arm64`

产物命名 `MacAppControlDeck-<version>-universal.zip/.dmg`，appcast 只登记这一份，避免 Sparkle 无法按架构挑选。

## 5. Sparkle.framework 嵌入

SwiftPM binary target 会把框架放在 `.build*/artifacts/sparkle/Sparkle/Sparkle.framework`，但不会把 `.app` 组装好。构建脚本负责：

1. `cp -R` 到 `Contents/Frameworks/`；
2. 若 `otool -l` 里没有 `@executable_path/../Frameworks`，用 `install_name_tool -add_rpath` 补；
3. 签名顺序：Sparkle 自带的 `Installer.xpc` / `Downloader.xpc` / `Autoupdate.app` 先按我们的身份重签，再签 framework，最后签外层 App（不用 `--deep`，按 R2 显式列出）；
4. `deck_assert_stable_signature` 仍然只校验外层 DR，保持不变。

## 6. 发版流水线

```
push tag v0.4.0
   ↓
GitHub Actions (macos-14)
   ├─ 导入 DECK_SIGN_P12_BASE64 → 临时 keychain → 得到 MacAppControlDeck Self-Signed
   ├─ swift build ×2 → lipo → 组装 .app → 签名（外层 DR 断言）
   ├─ ditto -c -k --sequesterRsrc --keepParent → ZIP
   ├─ hdiutil → DMG
   ├─ generate_appcast（EdDSA 私钥来自 Secrets）→ appcast.xml
   ├─ shasum -a 256 → SHA256SUMS.txt
   └─ gh release create v0.4.0 <zip> <dmg> <appcast.xml> <SHA256SUMS.txt>
```

- `releases/latest/download/appcast.xml` 是稳定 URL，不需要 Pages。
- 若不发版只想试跑：`workflow_dispatch` 用当前 `CFBundleVersion` 生成 `-dryrun` 附件，不创建 Release。

## 7. 运行时行为

- `UpdateController` 在 `applicationDidFinishLaunching` 最后启动（菜单栏装好之后），避免 Sparkle 在状态栏未就绪时弹窗。
- 自动检查失败（断网 / GitHub 不可达）静默忽略，只在用户手动点「检查更新…」时才提示错误。
- 下载完成 → Sparkle 标准弹窗「重启以完成更新」，用户点「安装并重启」才替换；录屏 / 桌宠运行中不阻止，但更新后进程重启会中断，与现有退出行为一致。
- `DECK_UPDATE_FEED` 非空时用 delegate 覆盖 feed URL，用于本机端到端验证。

## 8. 安全边界

- 私钥只存在本机钥匙串与 GitHub Secrets，不进仓库、不进日志。
- 没有 EdDSA 签名的包一律拒绝；`SHA256SUMS.txt` 仅用于人工校验，不作为信任来源。
- 签名身份与 Bundle ID 均不可变（R2）；证书重建必须同步更新 Secrets，否则自动更新会因 DR 不匹配被系统拦下或 TCC 失效。
