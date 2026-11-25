# 区域截图钉图落在原截图位置

## 背景

区域截图（F1 / ⌘⇧X）框选后点击「钉住」，图片会跳到屏幕中心，而不是停留在刚刚框选的位置，用户需要重新拖动找回原位。

上游 `OverlayWindowController.pinSource(capturedSize:)` 在 dismiss 之前已经算出了选区的全局屏幕坐标（`PinSource`），并通过 `overlayDidRequestPin(..., source:)` 传给宿主。但本仓库的 `OverlayCoordinator.overlayDidRequestPin` 接收了 `source` 却未使用，直接调用 `showPin(image:)`，创建 `PinWindowController(image:)` 时 `source` 为 nil。于是 `initialFrame` 里的「原位摆放」分支永远进不去，只能走默认的屏幕居中。此外 `PinPlacement` 的偏好开关没有任何 UI 入口，默认值又恰好是「居中」，即使传了 source 也会被它挡住。

## 目标

- 区域截图钉住的图片落在原框选位置（「在哪里截图的就 pin 在哪里」），无需手动拖回。
- 大图按原选区中心等比缩放，跨屏选区保持原尺寸，来源显示器不可用时回退居中。
- 历史 / 剪贴板 / 悬浮缩略图 / 编辑器等无来源的钉图保持居中不变。
- 不改变 Esc 关闭、缩放、编辑等既有钉图交互。

## 范围

改动 `Sources/MacShotKit/OverlayCoordinator.swift`（接通 source 传递）、`Sources/MacShotKit/Upstream/Overlay/PinWindowController.swift`（来源存在时强制原位）、新增定位单测，以及 `capture-overlay-parity` 规格与 README 反向链接。

## 实现

1. `overlayDidRequestPin` 把 `source` 传给新增的 `showPin(image:source:)`，再传入 `PinWindowController(image:source:)`；保留 `showPin(image:)` 供编辑器 / 缩略图等无来源路径使用。
2. `PinWindowController.placement(for:)`：有 `source` 返回 `.captureLocation`（不受旧偏好值干扰），无 `source` 沿用 `PinPlacement.current`。
3. `initialFrame` 既有的 `captureLocationFrame` 负责对齐选区、限制大图尺寸、处理跨屏与来源屏缺失，无需改动。
4. 新增 `PinPlacementTests` 覆盖原位/大图/跨屏/无来源居中/来源屏缺失/偏好干扰等场景。
