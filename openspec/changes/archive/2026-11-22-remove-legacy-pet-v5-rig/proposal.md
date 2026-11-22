# 提案：移除已弃用的 v5 桌宠图层运行时

## Why

桌面宠物的光栅渲染已在 `PetRasterRig` 中优先使用 v6 全身骨骼；v5「Living Rig」只作为永远到不了的中间回退保留。

v5 的问题不只是过时，而是体积严重失控：

- `Resources/v5` 共 35 MB，占发布 `.app` 的 56%。
- 12 个主要图层都按完整 1440×1920 画布导出，单张约 2.7 MB。
- 透明区域仍保留整张原图的 RGB，`earR` 只有 0.1% 可见像素也要 2.69 MB。
- 只要 v6 存在，v5 资产不会被加载，也不会进入任何正常渲染路径。

继续保留会持续把 35 MB 死资源打进每个架构的安装包，也会让后续维护误以为还有第三套渲染契约。

## What Changes

- 删除 `Sources/MacAppControlDeck/Modules/Pet/Resources/v5/` 全部图层与 manifest。
- 删除 `PetRasterV5.swift`（`PetV5Manifest` / `PetV5Assets` / `PetV5Renderer`）。
- `Package.swift` 不再复制 `Resources/v5`。
- 光栅回退链从 `v6 → v5 → v4 → 矢量` 收敛为 `v6 → v4 → 矢量`。
- 删除 `PetV5RigTests.swift`；把不依赖 v5 资产的状态机断言迁移到 `PetRasterStateTests.swift`，保留对 idle、眨眼、左右爪分区、真实键帽位置和头部偏航上限的覆盖。
- 清理源码注释与测试注释中的 v5 命名；把状态机内部变量 `v5Blink` 改为中性的 `blinkPulse`。
- 同步 `openspec/specs/desktop-pet/spec.md`：当前场景改为 v6 十七层，回退改为 `v6 → v4 → 矢量`，活动时钟改为 v6 优先。

**非目标**：

- 不移除 v4 光栅回退、矢量皮肤回退或 BongoCat Live2D 默认桌宠。
- 不改变桌宠外观、动画参数、键鼠响应、点击穿透、三档尺寸或任何用户可见行为。
- 不修改签名流程、Bundle ID、权限或发布协议。
- 不删除 v5 的历史 OpenSpec 归档、历史发布说明与设计归档；它们只作为历史决策记录，不再参与构建。
- 本次是既有模块内部资源清理，无新增模块或窗口，因此按 R0 不需要新增内置打开按钮。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `desktop-pet`：移除 v5 运行时契约，明确当前分层只有 v6 与 v4/矢量回退。

## Impact

- 代码：`Package.swift`、`Modules/Pet/PetRasterRig.swift`、`Modules/Pet/PetStateMachine.swift`。
- 删除：`Modules/Pet/PetRasterV5.swift`、`Modules/Pet/Resources/v5/`、`Tests/.../PetV5RigTests.swift`。
- 测试：新增 `Tests/.../PetRasterStateTests.swift`，保留通用状态机覆盖。
- 规范：`openspec/specs/desktop-pet/spec.md`。
- 体积预期：arm64 `.app` 约 62 MB → 24 MB，DMG 约 50.6 MB → 12 MB。
- 权限/API/数据：无新增权限、无接口变更、无数据迁移。
