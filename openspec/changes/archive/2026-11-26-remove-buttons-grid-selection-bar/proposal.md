# 提案：移除按钮管理的底部选中操作条

## Why

按钮网格点击卡片后，窗口底部会弹出一条「已选 xxx / 重命名… / 删除…」操作条。它会压缩网格可视高度、遮住最后一行卡片，并且与右键菜单的编辑能力重复。用户不需要这条底部弹层。

## What Changes

- 删除 `ButtonsSettingsView` 底部的 `selectionBar` 与 `safeAreaInset`。
- 点击卡片仍只做高亮选中，不执行按钮本身。
- 重命名、删除、编辑组合、上移、下移继续由右键菜单提供。
- 更新页面底部说明文字，不再写「点击选中」。
- 不改排序、拖动、搜索、折叠、数据模型。

## Capabilities

### Modified Capabilities

- `button-panel-config`：按钮管理不再提供底部选中操作条；编辑与排序全部走右键菜单。

## Impact

- 代码：`Sources/MacAppControlDeck/UI/ButtonsSettingsView.swift`。
- 无数据、API、签名变更。
- 无新增用户可见入口，沿用「设置 → 电脑控制 → 按钮」。
