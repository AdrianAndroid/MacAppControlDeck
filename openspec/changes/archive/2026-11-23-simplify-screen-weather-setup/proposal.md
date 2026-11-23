# 提案：简化副屏天气配置并拦截示例 Host

## Why

实际配置时用户把文档示例 `h2a9cf3mhs.xy.qweatherapi.com` 当成自己的 API Host，城市搜索直接报「未能找到使用指定主机名的服务器」。同时设置页把「天气」「认证」「城市」拆成三张卡片，步骤不直观，重复的成功提示也增加噪音。

## What Changes

- 把天气配置合并为一张卡片，按 1-2-3 三步排列：凭据 → 城市 → 测试并显示。
- JWT 不再默认展示，只在「改用 JWT 认证…」后出现；默认始终是 API Key 两项。
- 对 Host 做前置校验：
  - 文档示例 Host 直接提示「这是文档示例 Host，请换成控制台设置里的专属 Host」
  - 非 `qweatherapi.com` 后缀提示格式错误
- 网络错误翻译为可执行提示：DNS 解析失败、断网、超时、TLS 失败。
- 城市搜索失败时展示上述提示，而不是系统原始错误。
- 测试成功后自动打开「在副屏显示天气」，减少一次开关操作。
- 去掉重复的「已保存 / 已保存到钥匙串」两条提示。

**非目标**：

- 不改变天气接口、数据解析与缓存语义。
- 不改变副屏页面布局。
- 不自动填写 Host 或 Key。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：天气配置流程、Host 校验与错误提示。

## Impact

- 代码：`UI/ScreenSettingsView.swift`、`WeatherSettings.swift`、`WeatherService.swift`。
- 测试：示例 Host 拒绝、DNS 错误文案。
- 用户可见：设置页更短；错误能指向真正原因。
