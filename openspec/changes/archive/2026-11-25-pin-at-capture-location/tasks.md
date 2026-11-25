# 任务清单

- [x] 1. `OverlayCoordinator.overlayDidRequestPin` 把 `PinSource` 传到 `showPin(image:source:)` 与 `PinWindowController`。
- [x] 2. `PinWindowController.placement(for:)`：有来源强制 `.captureLocation`，无来源沿用偏好。
- [x] 3. 新增 `PinPlacementTests`，覆盖原位、大图、跨屏、来源屏缺失、无来源居中、偏好干扰。
- [x] 4. 更新 `capture-overlay-parity` 规格钉图位置语义，README 加反向链接。
- [x] 5. 全量测试、release 构建签名、覆盖安装验证。
