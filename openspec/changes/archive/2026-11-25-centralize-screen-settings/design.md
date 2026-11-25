# 设计：副屏设置统一到 Mac 端

## 架构

```
Mac 设置界面                Mac 服务端                  副屏页面
ScreenSettingsView  ──写入──▶ ScreenDisplaySettings
   (尺寸/桌宠/常亮)              │ (UserDefaults)
                                ├──GET /api/screen/display──▶ applyDisplay()
                                └──ScreenEventHub.publish()─▶ watchScreenEvents()
                                                                 │
                                                                 └──重新拉取配置
```

## 决策

1. **配置唯一来源在 Mac**：`ScreenDisplaySettings.shared` 是唯一写入口，通过 `@Published` 的 `didSet` 持久化并调用 `ScreenEventHub.notifyChange()`，副屏无需等待 30 秒轮询。
2. **只读下端点**：`GET /api/screen/display` 返回归一化后的 `ScreenDisplayConfig`，与 `/api/screen/frame`、`/api/screen/countdown` 同属公开只读端点，不下发凭据或坐标。
3. **换宠 nonce**：固定模式下点「立即换一只」直接把 `petId` 前进到下一只；随机模式下递增 `petSwitchNonce`，副屏对比 nonce 变化后重置洗牌队列并换宠。这样两种模式都能从 Mac 端触发。
4. **随机轮播不被刷新打断**：副屏区分「首次应用 / 参数变化 / 换宠」与「普通刷新」，后者只重排程，不重置当前随机宠物。
5. **HTML 资源化**：`ScreenHTML.content` 从 1919 行 Swift 多行字符串移到 `Panel/Screen/index.html` 资源，运行时替换 `%%SCREEN_VERSION%%`。以后改副屏页面只复制资源，不重编译 Swift module（实测 release 构建 6.5 分钟 → 4 秒）。

## 副屏控制条最终形态

- `↻` 强制刷新：重新拉取时间、天气、倒计时、外观、显示配置。
- `全屏`：浏览器支持 `requestFullscreen` 时显示（WKWebView / iOS Safari 不显示）。

不再出现：尺寸 `小/中/大`、桌宠 `⚙` 设置面板、常亮状态文字。

## 配置字段

```json
{
  "size": "s" | "m" | "l",
  "petMode": "fixed" | "random",
  "petId": "cat" | "dog" | "robot",
  "petInterval": 30 | 60 | 300 | 900,
  "keepAwake": true | false,
  "petSwitchNonce": 0, 1, 2, ...
}
```
