# 提案：天气凭据迁移到本地 0600 文件

## Why

自签名 App 每次重建后，钥匙串 ACL 不再信任新二进制，macOS 会弹出「输入登录钥匙串密码」对话框；点「始终允许」也只能维持到下一次重建。这会反复打断使用。

## What Changes

- 天气 API Key 与 JWT 私钥改存 `~/Library/Application Support/MacAppControlDeck/weather-secrets.json`。
- 文件权限 0600、目录 0700，仅当前用户可读；不使用钥匙串，不再弹授权/密码框。
- 进程内缓存，避免频繁读盘。
- 设置页与 README 明确说明存储位置、权限与「升级后需重新粘贴一次 Key」。
- 旧钥匙串条目不再读取（可保留，不再触发弹窗）。

**安全取舍**：

- 代价是 Key 以明文存磁盘（依赖用户账户权限与 FileVault），而不是钥匙串加密。
- 收益是彻底消除反复索要钥匙串密码的弹窗；对单用户本机工具可接受。

**非目标**：

- 不做密钥加密、不同步到 iCloud。
- 不迁移旧钥匙串内容（迁移需要再次输入密码，违背目标）。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：天气凭据存储位置与权限。

## Impact

- 代码：新增 `WeatherSecretStore`；`QWeatherAuth` 改用文件；UI/README 文案。
- 用户可见：升级后需重新粘贴一次 API Key；之后不再弹钥匙串。
