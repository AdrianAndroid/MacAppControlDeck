# 提案：按钮管理改为卡片网格与长按拖动排序

## Why

「设置 → 电脑控制 → 按钮」目前是纵向行列表。按钮一多就变成长条滚动，名称、Bundle ID、上下移按钮和行尾菜单挤在一行，既难扫视，也和手机面板图标优先的卡片网格不一致。排序需要反复点上移/下移，重命名与删除又藏在行尾菜单里。

## What Changes

- 按钮页改为分组卡片网格：应用、快捷操作各自 4 列，卡片为图标在上、名称与类型在下。
- 点击卡片即选中，不执行按钮本身；底部出现选中操作条，提供重命名、删除，快捷操作额外提供编辑组合。
- 长按 0.5 秒进入拖动准备态，随后移动进入组内排序；松手一次落盘。
- 移除卡片上的上移/下移按钮和行尾 `…`；右键菜单保留重命名、删除、上移、下移作为鼠标与无障碍兜底。
- 增加搜索（按钮总数超过 12 个时出现）和分组折叠；搜索状态下禁用拖动排序。
- 新增纯函数 `ButtonGridReorder`，负责“指针位置 → 插入序号”的换算，并补单元测试。

**非目标**：

- 不改变按钮数据模型、`buttons.json` 结构、HTTP API 或手机面板只读边界。
- 不允许应用组与快捷组跨组混排；跨组排序需要改 `ConfigStore.kindRank`，另行评审。
- 不新增独立窗口或模块。本次是既有「按钮管理」交互升级，沿用现有设置入口，因此按 R0 无新增用户可见入口。
- 不改签名、权限、发布流程。
      

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `button-panel-config`：按钮管理从行列表改为分组卡片网格；新增选中操作条、长按拖动排序、搜索与右键兜底。

## Impact

- 代码：`Sources/MacAppControlDeck/UI/ButtonsSettingsView.swift`，新增 `Sources/MacAppControlDeck/UI/ButtonGridSupport.swift`。
- 数据：无迁移；复用既有 `sortOrder` 与 `DeckState.moveToIndex`。
- API：无新增或修改端点。
- 测试：新增 `ButtonGridReorderTests`；手工验证点击、长按、拖动、右键、搜索与滚动。
- 规范：归档时同步 `openspec/specs/button-panel-config/spec.md`。
