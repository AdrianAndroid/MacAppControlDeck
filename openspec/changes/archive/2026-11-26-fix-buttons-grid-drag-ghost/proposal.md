# 提案：修复按钮长按拖动浮层不跟手

## Why

按钮网格把拖动状态机挂在单张卡片上。长按 0.5 秒进入拖动后，`entries(for:)` 会把被拖卡片从网格替换成占位视图；卡片一旦从视图树移除，SwiftUI 就会取消它的 `DragGesture`，后续 `onChanged` 不再到达。结果是卡片浮起后停在原地，浮层不跟随鼠标，也无法持续更新排序位置。

## What Changes

- 把按压/拖动 `DragGesture` 从单张卡片移到每组 `LazyVGrid` 容器上；容器在整段拖动中始终存在，手势不会被占位视图替换打断。
- 按下时用当前卡片 frame 命中起始点，得到被按下的按钮；后续状态机逻辑保持不变。
- 卡片保留右键菜单、悬停、帮助与辅助功能动作；点击选中仍由容器手势统一处理。
- 不改变数据模型、排序写入时机或组内排序规则。

## Capabilities

### Modified Capabilities

- `button-panel-config`：明确长按拖动过程中浮层必须持续跟随指针，插入空隙随指针实时更新。

## Impact

- 代码：`Sources/MacAppControlDeck/UI/ButtonsSettingsView.swift`。
- 测试：`ButtonGridReorderTests` 继续覆盖落位计算；新增系统级长按拖动回放验证。
- 无数据迁移、无 API 变更、无签名变更。
- 无新增用户可见入口，沿用「设置 → 电脑控制 → 按钮」。
