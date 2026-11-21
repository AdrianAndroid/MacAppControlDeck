# 技术设计：F1 区域截图全局快捷键

## 1. 注册方式

沿用 `GlobalHotKeys` 现有的 Carbon `RegisterEventHotKey`：

```swift
Binding(id: 9,
        keyCode: UInt32(kVK_F1),   // 122
        modifiers: 0,
        action: { ... captureArea ... })
```

- keyCode 使用 `kVK_F1`，不写裸数字，避免键码漂移。
- 无修饰键，符合 Snipaste 的 `F1` 使用习惯。
- 使用独立 id `9`，不与现有 1–8 冲突。
- `GlobalHotKeys` 已有注册失败收集与 2 秒重试机制，F1 被其他程序占用时自动进入重试队列，不新增逻辑。

## 2. 触发路径

```swift
Binding(id: 9, keyCode: UInt32(kVK_F1), modifiers: 0,
        action: {
            MainActor.assumeIsolated {
                CaptureModule.shared.captureArea()
            }
        })
```

选择 `CaptureModule.shared.captureArea()` 而不是直接调用 `MacShotController.shared.captureArea()`：

- `CaptureModule.captureArea()` 会先 `syncDirectories()`，同步保存目录、录屏目录、格式、质量、延时、快门音、剪贴板与悬浮缩略图等偏好。
- 用户在设置页改了延时或格式后，F1 立即使用最新配置，不会像直接调用 controller 那样沿用旧值。

## 3. 与现有快捷键并存

- `⌘⇧X` 继续保留，F1 与它都进入同一个 `captureArea()`。
- 覆盖层协调器已实现“打开前丢弃上一轮未结束的 overlay”，连续按 F1 不会叠加遮罩。
- 不把 F1 写入 `NSMenuItem.keyEquivalent`，避免菜单打开时再触发一次；菜单展示保持原样，通过设置页与 README 告知快捷键。

## 4. 可发现性

- `CaptureSettingsView` 的「截图」卡片增加说明：`快捷键 F1 直接打开区域截图；⌘⇧X 同样可用。`
- README「截图、录屏与视频剪辑」章节开头与使用步骤第 1 条写明 F1。
- `Docs/architecture/MACSHOT_PORT.md` 的全局快捷键清单加入 F1。

## 5. 键盘模式限制

Carbon 全局热键只能接收“标准功能键”事件：

- Apple 键盘默认把 F1 映射为降低亮度，按下时产生系统媒体事件，应用收不到 keyCode 122。
- 需要用户在「系统设置 → 键盘 → 将 F1、F2 等键用作标准功能键」打开，或按住 `fn` 使用。
- 该限制与 Snipaste 的说明一致，不是本程序可以绕过的系统行为；不尝试用私有 API 抢媒体键。

## 6. 冲突与取舍

- **手机端 F1 按钮**：应用运行期间，系统级 F1 会先被 Deck 截获并打开区域截图，不再透传给目标应用。这是全局快捷键的固有代价；如需向目标应用发送 F1，可临时退出 Deck 或改用命令按钮。README 已知限制中补充。
- **其他应用占用 F1**：注册失败时沿用现有重试；若长期失败，F1 不生效，但 `⌘⇧X` 仍可用。
- **不提供自定义**：本次按用户明确诉求固定 F1，避免引入快捷键编辑、冲突检测与持久化的一整套 UI；后续确有需要再单独立项。
