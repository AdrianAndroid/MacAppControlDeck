# Change: 副屏底部宠物卡片加显示开关

## Why

副屏底部的「像素猫」卡片占掉时钟栏 120px 高的 dock 区，只想看时间和月历的人没法关掉它（竖屏本来就隐藏，横屏却强制显示）。

## What Changes

1. `ScreenDisplayConfig` 新增 `petVisible`（默认 `true`），随 `/api/screen/display` 下发；`normalized` 保持向后兼容（旧配置缺字段按 `true`）。
2. 设置 → 副屏 →「副屏显示与桌宠」新增开关「在副屏显示底部宠物卡片」。
3. 副屏页面按 `data-pet` 显隐：关闭时 `.pet-dock { display: none }`，时钟区顺势变高，表盘随之变大。

## Capabilities

- `remote-web-panel`（修改）：副屏宠物卡片可见性。

## Impact

- `Modules/RemoteControl/ScreenDisplaySettings.swift`、`UI/ScreenSettingsView.swift`、`Panel/Screen/index.html`。
- 旧配置无该键时默认为显示，行为不变。

## Non-goals

- 不改桌宠模型/换宠逻辑，也不改 Mac 桌面宠物。
- 不在副屏页面提供开关（副屏仍只读）。
