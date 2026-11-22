# 任务清单：remove-legacy-pet-v5-rig

## 1. 移除运行时

- [x] 1.1 删除 `Sources/MacAppControlDeck/Modules/Pet/Resources/v5/`
- [x] 1.2 删除 `Sources/MacAppControlDeck/Modules/Pet/PetRasterV5.swift`
- [x] 1.3 `Package.swift` 移除 `Resources/v5` 资源声明
- [x] 1.4 `PetRasterRig.swift` 回退链改为 `v6 → v4 → 矢量`
- [x] 1.5 清理源码注释与 `v5Blink` 命名

## 2. 测试与规范

- [x] 2.1 删除 `PetV5RigTests.swift`
- [x] 2.2 新增 `PetRasterStateTests.swift`，保留通用状态机断言
- [x] 2.3 更新 `openspec/specs/desktop-pet/spec.md`
- [x] 2.4 全仓确认无 `PetV5`、`Resources/v5` 运行时引用

## 3. 验证

- [x] 3.1 `swift build -c release` 通过
- [x] 3.2 `swift test` 103 项，101 通过，2 个既有 `PetPanelControllerTests` 窗口尺寸失败
- [x] 3.3 `./Build/build.sh` 组装与固定签名通过
- [x] 3.4 产物 `.app` 内不存在 `v5` 目录；`.app` 27 MB，试算 DMG 15 MB
- [x] 3.5 `./Build/verify-signing.sh` 稳定签名校验通过

## 4. 归档

- [x] 4.1 变更移入 `openspec/changes/archive/2026-11-22-remove-legacy-pet-v5-rig/`
- [x] 4.2 记录最终体积与测试结果
