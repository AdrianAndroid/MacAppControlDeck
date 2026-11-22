# 设计：移除 v5 桌宠运行时

## 当前渲染链

`PetRasterRenderer.draw` 的实际顺序：

1. `PetV6Assets.shared != nil` → `PetV6Renderer`
2. `PetV5Assets.shared != nil` → `PetV5Renderer`
3. `PetRasterAssets.shared != nil` → v4 单帧 + 头/眼
4. 都缺失 → 矢量皮肤

发布包始终带 v6，所以第 2 步不可达。

## 目标渲染链

1. `PetV6Assets.shared != nil` → `PetV6Renderer`
2. `PetRasterAssets.shared != nil` → v4 单帧 + 头/眼
3. 都缺失 → 矢量皮肤

v5 的类型、资源定位和绘制代码一并删除，避免留下无调用者的第三套契约。

## 资源与体积

| 项目 | 当前 | 移除 v5 后（实测试算） |
|---|---:|---:|
| `.app` | 62 MB | 24 MB |
| arm64 DMG | 50.6 MB | 约 12 MB |
| `Resources/v5` | 35 MB | 0 |

v4 保留 2.3 MB，作为 v6 缺失时的最后一层光栅回退；矢量皮肤仍保留。

## 测试策略

删除 v5 专属资产契约测试：

- manifest 画布与锚点
- v5 图层文件存在性
- v5 渲染器加载
- v5 资产驱动的瞳孔像素检查

迁移与渲染实现无关的通用状态机断言到 `PetRasterStateTests`：

- idle 帧中性
- 双眼共享眨眼标量
- 左右半屏按键分别驱动左右爪
- 键帽携带真实 keyCode 行列
- 头部偏航不超过 6.5°

这样测试数量会减少，但 v6 渲染仍由 `PetV6RigTests` 覆盖，状态机覆盖不丢失。

## 风险与缓解

- **误删 v4 回退**：只删除 `Resources/v5` 和 `PetRasterV5.swift`；`v4` 的 `PetRasterAssets`、`PetRasterRenderer` 分支保持不动。
- **测试仍引用 v5 类型**：删除 `PetV5RigTests.swift`；全仓 `grep` 确认没有 `PetV5`/`Resources/v5` 残留。
- **发布包仍夹带 v5**：重新执行 `swift build -c release` 与 `./Build/package-release.sh`，直接检查产物 bundle 中不存在 `v5` 目录。
- **签名变化**：只改包内容，不改签名身份与脚本；构建后仍执行 `Build/verify-signing.sh`。
