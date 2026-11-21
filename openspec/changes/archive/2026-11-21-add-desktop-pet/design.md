# 技术设计：桌面宠物

## 结构

```text
PetModule（轻量代理）
└── PetRuntime?
      ├── PetSettings
      ├── PetStateMachine
      ├── PetPanelController
      │     ├── PetPanel
      │     ├── PetContentView
      │     └── PetSceneView（SwiftUI Canvas）
      ├── PetInputMonitor（CGEventTap）
      └── PetPositionStore
```

## 生命周期

```text
打开桌宠 / ⌃⌥P / pet.open
→ PetModule.ensureRuntime()
→ 创建 PetRuntime（设置、状态机、面板、输入监听）
→ PetPanelController.show()
→ 启动输入监听（有权限时）

关闭桌宠
→ settings.visible=false
→ PetRuntime.stop()
→ 停止 tap、指针轮询、动画时钟
→ 释放 panel / hosting / state
```

`暂停互动` 只停止输入和随机动作，保留面板和呼吸/眨眼。关闭窗口或关闭模块才释放 runtime。

## 面板与尺寸

- `NSPanel` 子类，`styleMask=[.borderless, .nonactivatingPanel]`。
- `level=.floating`，`isOpaque=false`，`backgroundColor=.clear`，`hasShadow=false`。
- `canBecomeKey=false`、`canBecomeMain=false`、`acceptsFirstMouse=true`。
- 默认 `collectionBehavior=[.canJoinAllSpaces]`；开启“允许覆盖全屏”时追加 `.fullScreenAuxiliary`。
- 基准视觉槽位 `240 × 140`，窗口额外 4pt 抗锯齿留边。
- 三档：0.75 / 1.0 / 1.35。
- 位置以屏幕 UUID + 归一化坐标保存；默认主屏右下角、Dock 上方 24pt。

## 点击拦截

- `PetSkin.hitRects` 提供归一化的身体、头部、键盘矩形。
- `PetGeometry.hitPath` 生成椭圆/圆角矩形 union。
- 窗口只包住视觉槽位；透明区域不进入 hit path。
- `PetPanelController` 根据全局鼠标位置切换 `ignoresMouseEvents`：
  - 在 hit path 内：false；
  - 离开 4pt 滞回：true；
  - 有输入监控时由 CGEventTap 更新；无权限时 30Hz `NSEvent.mouseLocation` 轮询；仍失败则紧贴窗口矩形拦截。
- 点击穿透模式直接把 `ignoresMouseEvents=true`，只能从菜单栏或 `⌃⌥P` 恢复。

## 皮肤

- `PetSkin`：`bodyKind`、`pattern`、`palette`、`hitRects`、`anchors`、`keyboardTheme`。
- 五套皮肤：白猫、黑猫、橘猫、三花、小狗；共用身体骨架，狗只换耳/尾/口鼻。
- 渲染使用 SwiftUI `Canvas` 矢量路径，不加载位图，天然支持透明和缩放。
- 小档隐藏键帽文字、减少胡须；大档完整细节。
- 换肤 150ms 淡入 + 轻微弹动；先计算新 frame，再更新 hit path，最后动画。

## 输入与状态机

- `CGEventTap`：`.cgSessionEventTap`、`.listenOnly`、`.headInsertEventTap`，监听 keyDown/Up、flagsChanged、mouseMoved、mouseDown、scrollWheel。
- 只读 `keyCode`、左右区域、autorepeat；不读字符、不写日志。
- `IsSecureEventInputEnabled()` 为 true 时忽略键盘事件；锁屏/休眠停 tap，解锁/唤醒恢复。
- `tapDisabledByTimeout` / `tapDisabledByUserInput` 自动重建。
- 键盘分区：left / right / center / function；未知键归 none。
- 组合键：120ms 内 3 个不同键 -> 惊讶 800ms。
- 鼠标：30Hz 节流，瞳孔/头部偏移；靠近爪子抬爪。
- 动画时钟：空闲 12fps，动作 30fps；遮挡/隐藏/低电量降帧。

## 权限与隐私

- 输入监控：`CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()`。
- 无权限：静态模式，显示、眨眼、鼠标跟随仍可用。
- 不记录按键文本、不联网、不写键盘日志。
- 只持久化：visible、skin、size、position、theme、偏好开关。
- 锁屏、休眠、Secure Input 均暂停键盘反应。

## 验收

- 三档窗口和 hit path 同步缩放；点猫外 4pt 能穿透。
- 五套皮肤在 S/M/L 下均可读；换肤不跳位置。
- 按键到爪子 < 80ms；长按不抖；无键盘文本日志。
- 无权限时静态模式可用；授权后无需重启恢复键盘反应。
- 空闲 CPU < 2%，持续打字 < 8%，内存 < 60MB。
- 关闭后 runtime、窗口、tap、定时器全部释放。
