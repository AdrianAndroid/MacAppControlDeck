# 2026-11-23 · 重装、面板横屏时钟与傻瓜安装包

## 背景

- 用户卸载应用后需要重新安装，且要求「后续版本签名保持一致」。
- 使用中发现钥匙串里原固定证书 `E8357462…` 已不存在，只剩私钥完好的 `MacAppControlDeck Self-Signed`（`145AEA72…`），但信任设置丢失，`codesign` 报 `CSSMERR_TP_NOT_TRUSTED`。
- 老板把 arm64 包发给同事后反馈「安装了没反应」，需要一套对方能自助完成的安装路径。

## 这一轮做了什么

### 1. 恢复固定签名身份（指纹变更）

- 用 `security add-trusted-cert -p codeSign` 把现有 `MacAppControlDeck Self-Signed` 的信任设为「代码签名」，从「仅 cdhash」状态恢复为可用身份。
- 之后所有构建的 designated requirement 为
  `identifier "com.zhaojian.MacAppControlDeck" and certificate root = H"145aea72352c419cccd76d6536bc70e14b2e134f"`。
- `Build/signing.sh`、`AGENTS.md` R2、`README.md`、`openspec/specs/stable-code-signing/spec.md` 的指纹同步更新，并写明「证书重建/重信任后 TCC 授权需重新授予一次」。
- OpenSpec：[`refresh-signing-fingerprint-docs`](../../../openspec/changes/archive/2026-11-23-refresh-signing-fingerprint-docs/proposal.md)

### 2. 手机面板横屏系统时钟

- 标题栏新增 `#clock`，仅在横屏显示 `2026年11月23日 星期一 10:33:21`，每秒刷新，等宽数字；竖屏隐藏。
- 时钟配色为鲜艳红 `#ff3b30`、加粗并带同色柔光（后续变更 `tint-panel-clock-red`）。
- `PanelHTML.version` 提升到 `2026-11-23.3`，已打开的面板通过 `/api/panel-version` 自动刷新。
- 右上角「已连接」徽标可点击，触发 `/panel/?v=<版本>&t=<时间戳>` 强制刷新（变更 `add-panel-force-refresh`）。
- OpenSpec：[`add-panel-landscape-clock`](../../../openspec/changes/archive/2026-11-23-add-panel-landscape-clock/proposal.md) · 规格 [`remote-web-panel`](../../../openspec/specs/remote-web-panel/spec.md)

### 3. 双击安装脚本

- 新增 `Build/install-friendly.command`：定位 App → 芯片架构校验 → 关旧实例 → `ditto` 复制到 `/Applications`（必要时管理员授权）→ 去 quarantine/provenance → 签名校验（受损时本机临时签名兜底）→ 启动 → 确认进程存活 → 结果弹窗。
- 失败路径全部弹窗，并输出 `spctl` 判定与最近崩溃报告摘要到 `/tmp/deck-install.log`。
- 新增 `Build/install-readme.txt`，DMG 内附带。
- OpenSpec：[`add-friendly-installer`](../../../openspec/changes/archive/2026-11-23-add-friendly-installer/proposal.md) · 规格 [`release-installer`](../../../openspec/specs/release-installer/spec.md)

### 4. 设置页深链接（安装后直达桌宠设置）

- `Build/Info.plist` 注册 `macappcontroldeck` scheme；`DeckApp` 处理 `application(_:open:)`，支持
  `macappcontroldeck://settings/pet` 与 `macappcontroldeck://settings?tab=pet`，覆盖 general / menu / modules / capture / sketch / calendar / pet / buttons / devices / service / about。
- 未完成启动时先缓存目标页，启动完成后立即打开设置窗口，避免空窗口。
- 安装脚本成功后执行 `open macappcontroldeck://settings/pet`（最多重试 6 次），失败则弹窗给「菜单栏 → 设置 → 桌面宠物」手动路径；新增 EXIT trap，未预期失败也弹窗。
- OpenSpec：[`add-pet-settings-deeplink`](../../../openspec/changes/archive/2026-11-23-add-pet-settings-deeplink/proposal.md) · 规格 [`settings-deeplink`](../../../openspec/specs/settings-deeplink/spec.md)

### 5. 聊天软件传输用的 ZIP

- 对方电脑不能在线下载，只能通过聊天框收文件。ZIP 改为包含同名文件夹：`MacAppControlDeck-0.3.1-arm64/`，内含 App、`安装 MacAppControlDeck.command`、`安装说明.txt`。
- DMG 与 ZIP 从同一组装目录生成，内容一致（DMG 多一个 Applications 快捷方式）；校验和重新生成。
- OpenSpec：[`add-chat-transfer-bundle`](../../../openspec/changes/archive/2026-11-23-add-chat-transfer-bundle/proposal.md)

## 排查记录

- 「iPhone 横竖屏没适配」：服务端实测正常（`/panel/` 302 到 `?v=2026-11-22.2`，响应 `Cache-Control: no-store`，HTML 含横屏右栏与竖屏 2 列），结论是手机端缓存了旧面板，强刷后恢复。
- 「装了没反应」：本机清空偏好模拟全新首次启动，进程正常且桌宠自动出现，说明程序本身没问题；对方大概率是被 Gatekeeper 拦在启动前，或从 DMG/下载目录直接双击。
- **实测结论：带 `com.apple.quarantine` 的 `.command` 无法直接双击运行**（LaunchServices 报 -128，脚本未执行）。首次必须「右键 → 打开」；脚本自身无法绕过（拦截发生在脚本执行之前）。

## 验证

| 项 | 结果 |
| --- | --- |
| `swift test` | 103 项，101 通过；2 个失败为已知桌宠窗口尺寸断言（`PetPanelControllerTests.testShowCreatesWindowAtConfiguredSize` / `testResizeKeepsBottomCenterAndUpdatesWindowSize`） |
| 面板时钟 | iframe 模拟 844×390 横屏显示并每秒跳动、390×844 竖屏隐藏；844×390 / 667×375 / 568×320 均无 header 溢出；计算样式 `rgb(255, 59, 48)` / `font-weight 700` |
| 深链接 | `open macappcontroldeck://settings/pet` 打开设置并停在「桌面宠物」页 |
| 安装脚本 | 沙箱（`DECK_INSTALL_DIR`）安装成功、quarantine 被清除、缺失 App 时退出码 1 并弹窗、只读 DMG 内运行成功 |
| 发布包 | `unzip` 后目录含 App/脚本/说明；DMG 内容一致；`shasum -a 256 -c SHA256SUMS.txt` 全部 OK |
| 签名 | `./Build/verify-signing.sh /Applications/MacAppControlDeck.app` 输出「稳定签名」 |

## 产物

```text
BuildOutput/release/arm64/
├── MacAppControlDeck-0.3.1-arm64.zip      13 MB   ← 聊天软件发送这个
├── MacAppControlDeck-0.3.1-arm64.dmg      15 MB
└── SHA256SUMS.txt
```

当前校验和（2026-11-23 11:50 构建，含红色时钟与强制刷新）：

```text
d2721e165685f26efce36ffea5dc46df2134fadddcbf5f8e42570af1056fe84d  MacAppControlDeck-0.3.1-arm64.zip
9494d7a5bc26ad321966664e6289bba8ee6d915da6af99368b91d81fe4ad4f74  MacAppControlDeck-0.3.1-arm64.dmg
```

## 已知限制

- 发布包未公证、证书不被对方机器信任：首次运行脚本需「右键 → 打开」，App 本身由脚本去隔离后可直接启动。
- 想让桌宠响应真实键盘/鼠标，需要在「系统设置 → 隐私与安全性 → 输入监控」人工授权一次。
- 自签名证书重建后指纹变化，旧 TCC 授权不匹配，需要按新身份重新授予。
