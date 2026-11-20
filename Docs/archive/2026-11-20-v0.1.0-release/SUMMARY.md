# 2026-11-20 · v0.1.0 归档与双架构发布

## 版本

- `CFBundleShortVersionString` = 0.1.0
- `CFBundleVersion` = 1
- Git tag：`v0.1.0`
- 归档基线：`10aa305`（weak-link ScreenCaptureKit，面板 302 测试修复）及其后的发布文档、打包脚本提交

## 目标

把当前功能冻结为一个可下载版本，并分别提供 Apple Silicon 与 Intel 两个原生架构安装包，避免用户依赖 Rosetta。

## 交付

- GitHub Release：`v0.1.0`
- `MacAppControlDeck-0.1.0-arm64.dmg` / `.zip`
- `MacAppControlDeck-0.1.0-x86_64.dmg` / `.zip`
- `SHA256SUMS.txt`
- 发布说明：[`Docs/releases/v0.1.0.md`](../../releases/v0.1.0.md)

## 构建方式

新增 `Build/package-release.sh`，按传入架构独立构建、组装、签名、压缩：

```zsh
./Build/package-release.sh arm64
./Build/package-release.sh x86_64
```

- 两个架构使用独立 scratch path：`.build-arm64`、`.build-x86_64`，互不污染
- 产物在 `BuildOutput/release/<arch>/`
- DMG 内含 `.app` 与 `/Applications` 快捷方式
- 同步生成 ZIP 和 `SHA256SUMS.txt`
- 打包使用 ad-hoc 签名（未公证）

## 验收结果

- `swift test`：全部通过（见 `/tmp/release-swift-test.log`）
- `lipo -archs`：arm64 包为 `arm64`，x86_64 包为 `x86_64`
- `codesign --verify --deep --strict`：两个架构均通过
- ZIP 解包与 DMG 挂载后，架构、签名、Applications 链接均复验通过
- 校验和：

```text
3f84a30558dd8f2fefdc0946b107439d6693d6541f1fa82b3e0d052376769161  MacAppControlDeck-0.1.0-arm64.zip
1d7206c58da2bfe44762a472cd5654d5a7d904e07f7ba132dd3363de0b7b1f84  MacAppControlDeck-0.1.0-arm64.dmg
b249289b488799b4f41fc65d446cbf4ea32bf7ee1e67465628a26e5f173b5e4f  MacAppControlDeck-0.1.0-x86_64.zip
f248b8f5c7b10f8a335cd8e2bfa846eeb34990c7922fd5dd08aa932475febba3  MacAppControlDeck-0.1.0-x86_64.dmg
```

## 已知边界

- 未签名公证，首次启动需要右键「打开」或移除 quarantine 属性
- 未接入自动更新
- Apple Silicon 包在本机（Intel）只能做交叉编译、签名和静态校验，未在真实 M 芯片机器上启动验证
- 辅助功能与屏幕录制授权仍按代码签名绑定，覆盖安装后可能需要重新授权

## 后续

- Excalidraw「UI 草图」模块仍在体积评估阶段，未纳入本版
- 若后续需要免提示分发，应补 Developer ID 签名与 Apple 公证
