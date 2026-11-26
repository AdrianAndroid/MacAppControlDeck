# 提案：副屏宠物卡「猫追老鼠」

## Why

副屏底部的宠物卡目前只有一只宠物在卡片里来回游走，长时间看是匀速平移，缺少"活着"的感觉。
猫追老鼠是最容易读懂的循环动作：老鼠在前跑、猫在后追，跑到边界直接掉头，
不需要用户操作，也不会打断时钟 / 月历 / 天气的阅读。

## What Changes

- 宠物卡新增**追逐层**（`#petChase`），内含猫、鼠两只像素精灵，与现有 `#petWalker` 互斥显示。
- 追逐只在宠物行为为 `idle` 时触发，跑完一次约 7 秒后回到普通游走；
  睡觉 / 打伞 / 围巾 / 看表 / 庆祝等状态不出现老鼠。
- 两只为**一对刚体**：鼠始终在猫头前方，同速同向；触到左右边界（留 8px）时
  方向取反并做位置镜像，鼠仍在前面、猫仍在后面，不重叠也不穿模。
- 素材：猫来自 OpenGameArt《Cat sprites》（CC0，6 帧跑动），鼠来自
  《Rodents – rat rework》（CC-BY 3.0，3 帧跑动）；猫原色为深灰，在黑底上不可见，
  入库时改为暖橙。两张帧条以 base64 内联进 `Screen/index.html`，不新增静态资源路由。
- 帧动画交给 CSS `steps()`，每帧只写 `translate3d` 与 `scaleX`，不读 DOM。
- 新增设置：副屏设置页「猫追老鼠」开关（默认开）与追逐间隔（30 秒 / 1 分钟 / 3 分钟）。
- `ScreenHTML.version` 提升到 `2026-11-27.7`。

**非目标**：

- 不做急刹、跃过、穿模、错身、尘土特效。
- 不接指针、不做点击互动（跟手方案已明确否决）。
- 不引入第三方二进制资源文件或新增路由。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：宠物卡新增猫追老鼠行为与对应设置。

## Impact

- 代码：`Panel/Screen/index.html`（CSS / DOM / 追逐逻辑）、
  `Modules/RemoteControl/ScreenDisplaySettings.swift`、`UI/ScreenSettingsView.swift`、
  `Panel/ScreenHTML.swift`（版本号）。
- 素材许可：猫 CC0；鼠 CC-BY 3.0，需在 `THIRD_PARTY_NOTICES.md` 署名。
- 权限/数据：无新增权限；设置存 `UserDefaults`，键前缀 `screen.display.pet.chase`。
- 入口：沿用现有副屏入口（菜单栏 / 手机面板「打开副屏」），无新增用户可见入口。
