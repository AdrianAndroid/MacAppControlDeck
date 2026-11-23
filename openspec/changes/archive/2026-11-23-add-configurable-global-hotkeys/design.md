# 设计：可配置的全局快捷键

## 配置模型

```swift
struct GlobalHotKeySetting: Codable { var combo: ShortcutCombo; var enabled: Bool }
struct GlobalHotKeyPreferences: Codable { var masterEnabled: Bool; var entries: [String: GlobalHotKeySetting] }
```

- 入口用稳定字符串 id（`capture.area`、`capture.area.f1`…）区分，Carbon 的 `UInt32` 只是注册时的编号。
- 缺失的入口自动补默认组合，未知 id 丢弃，升级不会丢配置也不会报错。
- 文件位于 `ConfigStore.defaultDirectory()/hotkeys.json`，`GlobalHotKeyStore` 可注入目录便于测试。

## 注册生命周期

`install()` 只装一次 Carbon 事件处理器；任何修改都走 `apply()`：

1. 先注销现有热键、取消重试定时器、清空动作表。
2. 总开关关闭 → 全部标记「全局关闭」，不注册。
3. 单项关闭 → 标记「已关闭」。
4. 本程序内组合重复 → 后一项标记「组合重复」，只注册第一项。
5. `RegisterEventHotKey` 失败 → 标记「被其他应用占用」，加入 2 秒重试队列。
6. 录制弹窗打开 → `suspend()` 注销全部；关闭 → `resume()` 重新 `apply()`。

## 校验

- 无修饰键只允许 F1–F12（keyCode 122/120/99/118/96/97/98/100/101/109/103/111），避免单个字母抢占全局。
- 只和「已启用」的其他入口比较重复，关闭状态的组合不阻塞改键，但重新启用时会再校验。
- 校验失败不写盘、不重注册，弹窗内红字提示。

## 菜单同步

`menuShortcut(for:)` 只在总开关开、捕捉项启用且主键是单字符时返回 key equivalent；`SketchModule` / `PetModule` 在每次菜单重建时读取，关闭后菜单不再显示快捷键。

## 取舍

- 不做 WebSocket/状态推送；设置页直接观察 `GlobalHotKeys` 的 `@Published` 状态。
- 冲突只在注册失败后显示，不预扫描其他进程，避免引入辅助功能或私有 API。
- 录制期间暂停全部热键，保证 F1 等能被录到；代价是弹窗打开时快捷键短暂失效。
