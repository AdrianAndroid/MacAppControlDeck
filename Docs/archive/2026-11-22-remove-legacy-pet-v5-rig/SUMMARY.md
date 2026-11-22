# 移除 v5 桌宠运行时归档摘要

- change-id：`remove-legacy-pet-v5-rig`
- 日期：2026-11-22
- OpenSpec：`openspec/changes/archive/2026-11-22-remove-legacy-pet-v5-rig/`

## 为什么删

v5「Living Rig」早于 v6 全身骨骼，实际渲染链为 `v6 → v5 → v4 → 矢量`，但发布包始终带 v6，v5 中间回退永远到不了。

`Resources/v5` 仍有 35 MB：

- 12 张主要图层都按 1440×1920 全画布导出，单张约 2.7 MB。
- 透明区域保留整张原图 RGB；`earR` 仅 0.1% 可见像素，文件仍有 2.69 MB。
- 在默认 BongoCat Live2D 模式下不会加载；关闭 Live2D 后也优先用 v6。

## 做了什么

- 删除 `Sources/MacAppControlDeck/Modules/Pet/Resources/v5/`。
- 删除 `PetRasterV5.swift`，移除 `PetV5Manifest / PetV5Assets / PetV5Renderer`。
- `Package.swift` 不再复制 `Resources/v5`。
- `PetRasterRig` 回退链收敛为 `v6 → v4 → 矢量`。
- 删除 `PetV5RigTests.swift`，新增 `PetRasterStateTests.swift` 保留 idle、眨眼、左右爪、键帽真实键位、头部偏航上限断言。
- 清理 `v5Blink` 命名与注释中的 v5 指向。
- 更新 `openspec/specs/desktop-pet/spec.md`。

## 验证结果

- `swift build -c release`：通过。
- `swift test`：103 项，101 通过；2 个既有 `PetPanelControllerTests` 窗口尺寸断言失败，与本次删除无关。
- `./Build/build.sh`：组装与固定自签名通过。
- `./Build/verify-signing.sh BuildOutput/MacAppControlDeck.app`：稳定签名，DR 校验通过。
- `BuildOutput/MacAppControlDeck.app`：27 MB，包内 `find` 无任何 `v5` 目录；仅剩 `v4 / v6 / live2d / Sketch`。
- 临时 UDZO DMG 试算：15 MB；挂载后再次检查无 `v5`。
- 删除前 arm64 DMG 为 50.6 MB，预计正式重新打包后降至约 15 MB。

## 保留项

- v4 光栅回退（2.3 MB）与矢量皮肤仍保留。
- v5 的历史 OpenSpec 归档、Docs 归档与 README 历史条目保留，只作为决策记录，不参与构建。
