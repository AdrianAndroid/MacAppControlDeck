# 提案：回退副屏「猫追老鼠」

## Why

「猫追老鼠」上线后，真机观察发现移动时角色边缘持续闪烁，观感不可接受。
根因指向两处：帧条按 3.1 倍放大却没有 `image-rendering: pixelated`，
以及逐帧 `translate3d` 落在非整数像素上，合成层做双线性插值后像素边抖动。

闪烁属于实现细节，不值得为了它让副屏长期带一个残影明显的动效。
先整体移除，素材、帧条生成脚本与设计文档全部保留，后续单独修。

## What Changes

- 移除副屏页面的追逐层：`--chase-cat` / `--chase-rat` 内联帧条、
  `.pet-chase` CSS 与 `chase-run` 关键帧、`#petChase` DOM、整套 `chase` 状态机。
- 恢复单只宠物游走，`petStep` 不再有追逐分支。
- 移除 `ScreenDisplayConfig` 的 `petChase` / `petChaseInterval` 与对应设置项。
- 保留 `Docs/design/pet-chase-candidates/`（素材、帧条、`build_assets.py`、预览页）
  与 `Docs/plans/2026-11-27-screen-pet-cat-chases-mouse.md`，供后续调整。
- `THIRD_PARTY_NOTICES.md` 改为「仅设计候选，未随 App 分发」。
- `ScreenHTML.version` 提升到 `2026-11-27.8`。

**非目标**：

- 不修闪烁本身（后续另开变更：补 `image-rendering: pixelated`、位移取整、
  或改用整帧 SVG）。
- 不动视口外边框。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：移除「宠物卡猫追老鼠」要求与对应配置字段。

## Impact

- 代码：`Panel/Screen/index.html`、`Modules/RemoteControl/ScreenDisplaySettings.swift`、
  `UI/ScreenSettingsView.swift`、`Panel/ScreenHTML.swift`。
- 数据：旧的 `screen.display.pet.chase` / `petChaseInterval` 键不再读取，留在
  `UserDefaults` 里无副作用。
- 入口：无新增或移除用户可见入口。
