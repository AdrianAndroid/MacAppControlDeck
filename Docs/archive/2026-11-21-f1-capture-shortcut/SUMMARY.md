# F1 区域截图全局快捷键（2026-11-21）

## 需求背景

用户长期使用 Snipaste 的 `F1` 启动区域截图，已经形成肌肉记忆。Snipaste 已从本机删除，用户希望 MacAppControlDeck 直接接管这个按键，不再每次点菜单栏。

## 目标

1. `F1` 在任意应用前台都能打开区域截图，行为与 Snipaste 的 F1 一致。
2. 保留已有 `⌘⇧X`，两个入口并存。
3. 不新增权限、HTTP 服务、模块或配置项。
4. 文档写清键盘功能键模式与 F1 占用时的处理方式。

## 实现

- `Sources/MacAppControlDeck/App/GlobalHotKeys.swift`
  - 新增 `BindingSpec(id: 9, keyCode: kVK_F1, modifiers: 0)`，即 `F1` 无修饰键。
  - 触发路径走 `CaptureModule.shared.captureArea()`，先同步截图偏好（目录、格式、质量、延时、剪贴板、快门音、悬浮缩略图），再打开覆盖层。
  - 沿用 Carbon `RegisterEventHotKey` 与现有的 2 秒失败重试队列。
- `Sources/MacAppControlDeck/Modules/Capture/CaptureSettingsView.swift`
  - 「截图」卡片增加提示：`F1` 直接打开区域截图，`⌘⇧X` 同样可用。
- `Tests/MacAppControlDeckTests/ShortcutActionsTests.swift`
  - 新增 `test_f1CaptureHotKeySpec`，校验 keyCode 122、无修饰键、热键 id 9。

## 文档

- `README.md`
  - 截图章节说明 F1 与 `⌘⇧X`。
  - 使用步骤第 1 条改为「按 F1 或 ⌘⇧X」。
  - 补充 F1 媒体键模式说明。
  - 故障排查新增 F1 不生效、手机端 F1 按钮被截获两条。
  - 测试数量 51 → 52。
- `Docs/architecture/MACSHOT_PORT.md`
  - 全局快捷键清单加入 F1，并写明标准功能键模式与全局优先级。

## 验证

- `swift test`：52 项全部通过，0 失败。
- `./Build/build.sh`：release 构建成功，使用 `MacAppControlDeck Self-Signed` 稳定签名，`codesign --verify` 通过。
- 覆盖安装到 `/Applications/MacAppControlDeck.app` 并重启。
- 合成 `keyCode 122`：桌面出现区域截图遮罩与选区工具，F1 生效。
- 合成 `⌘⇧X`：同样打开区域截图覆盖层。
- 连续两次 F1 后按一次 Esc：覆盖层完全退出，无残留遮罩，未出现叠层。

## 已知限制

- Apple 键盘默认把 F1 用作亮度键：需开启「将 F1、F2 等键用作标准功能键」，或按 `fn + F1`；不尝试私有 API 抢媒体键。
- F1 被其他程序占用时进入 2 秒重试；期间 `⌘⇧X` 仍可用。
- 应用运行期间 F1 为全局优先：手机端「F1」快捷按钮会被截获并打开区域截图，不再透传给目标应用。
- 本次固定 F1，不提供快捷键自定义 UI。

## 用户可见入口

无新增模块或打开入口。截图模块已有菜单「截图与录屏 → 区域截图」与内置操作 `capture.area`；本次只是给既有能力增加快捷方式，按 `AGENTS.md` R0 不需要重复新增打开按钮。

## 归档

- Docs 记录：`Docs/archive/2026-11-21-f1-capture-shortcut/SUMMARY.md`
- OpenSpec 变更：`openspec/changes/archive/2026-11-21-add-f1-capture-shortcut/`
- 能力规格：`openspec/specs/capture-overlay-parity/spec.md`
