# add-stable-code-signing · Design

## 签名身份

本机唯一的稳定身份：

- 名称：`MacAppControlDeck Self-Signed`
- SHA-1：`E83574620FE6CF96BA5A9C902F8B6A5C38F5A6B3`
- 证书：登录钥匙串中的自签名代码签名证书
- Bundle ID：`com.zhaojian.MacAppControlDeck`

自签名证书不加 hardened runtime。原因：该项目当前使用自签名，TCC 对自签名身份的 DR 依赖证书根哈希；一旦额外加 `--options runtime`，签名标志变化会导致旧授权不再匹配。Apple Development 身份则保留 `--options runtime`。

## designated requirement

稳定签名的 DR 必须是：

```text
identifier "com.zhaojian.MacAppControlDeck" and certificate root = H"e83574620fe6cf96ba5a9c902f8b6a5c38f5a6b3"
```

ad-hoc 的 DR 只有：

```text
cdhash H"..."
```

因此 `Build/signing.sh` 在签名后必须拒绝 `cdhash` 形式的 DR。

## 脚本边界

`Build/signing.sh` 提供：

- `deck_signing_identity`：优先 `DECK_SIGN_IDENTITY`，否则固定自签名名称。
- `deck_require_identity`：身份不存在时直接失败，不静默降级。
- `deck_sign_app <app>`：签嵌套 `KeySender`、签主 App、`codesign --verify`、校验 DR。
- `deck_assert_stable_signature <app>`：拒绝 ad-hoc，要求证书根或 Apple 锚点。

`Build/build.sh` 和 `Build/package-release.sh` 都 source 该文件，调用 `deck_sign_app`。

## ad-hoc 的显式例外

只有以下场景允许 ad-hoc：

- 没有本机证书的 CI/临时机器；
- 明确设置 `DECK_ALLOW_ADHOC=1`。

此时脚本必须打印醒目的“该包会重置 TCC 授权”提示，且规则要求不得把该包安装到日常使用的 `/Applications`。

## TCC 权限范围

需要保持的授权：

- 辅助功能（Accessibility）：跨桌面激活、Event Tap 等。
- 输入监控（Input Monitoring）：桌宠/快捷键读取物理按键。
- 屏幕录制（Screen Recording）：截图/录屏。
- 自动化（Automation）：通过 System Events 切换桌面。

这些权限都由代码签名身份匹配，不按 Bundle ID 无条件继承。

## 验证

1. `zsh -n Build/signing.sh Build/build.sh Build/package-release.sh Build/verify-signing.sh`
2. `./Build/build.sh`
3. `codesign -dv --verbose=4 BuildOutput/MacAppControlDeck.app` 显示 `Authority=MacAppControlDeck Self-Signed`
4. `codesign -d --requirements - BuildOutput/MacAppControlDeck.app` 显示证书根，而不是 `cdhash`
5. 覆盖安装到 `/Applications` 后运行 `./Build/verify-signing.sh`
