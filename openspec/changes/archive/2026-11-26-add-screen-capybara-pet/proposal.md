# Change: 副屏宠物新增「水豚」

## Why

副屏宠物只有 cat / dog / robot 三只，选项少、观感单调。调研（`Docs/research/2026-11-26-screen-pet-schemes.md`）后选定「水豚」作为第 4 只：只靠圆角矩形就能画得很像，头顶橘子是全网熟知的「松弛感」符号，且完全自绘、不引入任何第三方素材。

## What Changes

1. `PET_KEYS` / `PET_NAMES` 增加 `capybara`（水豚），`PET_ANCHORS` 补一套锚点，供状态道具（伞 / Zzz / 围巾 / 表 / 星 / 汗滴）复用。
2. 新增水豚造型：大圆身 + 小圆耳 + 方鼻 + 头顶橘子，腿色与身体同系（`#a3764e`）。
3. Mac 端 `ScreenDisplayConfig.validPetIDs` 增加 `capybara`，设置 → 副屏的「桌宠」分段变成 4 个选项；`normalized()` 对旧值保持兼容。
4. 页面新增只读 QA 参数 `?petId=`，用于本地预览任意宠物而不改设置。
5. `ScreenHTML.version` → `2026-11-27.2`。

## Capabilities

- `remote-web-panel`（修改）：副屏宠物可选项。

## Impact

- `Panel/Screen/index.html`（宠物造型与锚点）、`ScreenDisplaySettings.swift`、`ScreenSettingsView.swift`、版本号。
- 不改状态机、性能基线、Mac 桌面桌宠与 `/api/*`。

## Non-goals

- 不新增互动；不做多宠物同屏；史莱姆留待下一轮。
