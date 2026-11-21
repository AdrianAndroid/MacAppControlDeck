# AGENTS.md · 项目开发规则

本文件是后续任何开发（人类或 Agent）都必须遵守的项目级规则。

## R0. 每个新功能都必须有内置的快捷打开按钮

新增任何用户可见的功能、窗口、面板或模块时，必须同时提供 **开箱可用的内置快捷入口**，不能只藏在设置页、二级菜单或一行文档里。

### 强制清单

1. 在 `Sources/MacAppControlDeck/Control/BuiltinActions.swift` 的 `all` 中注册：
   - `id` 使用 `<feature>.open`，例如 `sketch.open`
   - `name` 使用「打开 X」，例如「打开 UI 草图」
   - `symbol` 提供一个易辨识字符
2. 在 `BuiltinActions.run` 的 `switch` 中接上实际打开动作。
3. 保证该入口在「设置 → 按钮管理 → 添加按钮 → 添加内置操作」中可直接添加。
4. 添加入口后，必须同时出现在：
   - 菜单栏「快捷操作」子菜单
   - 手机面板「快捷操作」区
5. 新增 `FeatureModule` 时，模块自己的菜单必须保留一个直接「打开」项，并配全局或菜单快捷键（如果该功能需要频繁使用）。
6. 提测/提交前必须验证：从「内置操作」添加后，点一下确实能打开目标功能；不能只验证配置写入。

### 不需要重复添加的情况

- 纯后台能力、纯数据迁移、内部重构：不需要新增打开按钮，但必须在提交说明中写明「无用户可见入口」。
- 一个已有打开按钮的功能内部新增子能力：沿用该功能的打开入口，不要求为每个子按钮单独建入口。

### 反例

- 只加「设置」页入口，没有快捷打开按钮 → 不合格。
- 只写在 README / 菜单二级深处 → 不合格。
- 内置操作能添加，但点了没反应 → 不合格。

## R1. 需求统一用 OpenSpec 管理

任何需求在动手前，必须先在 `openspec/changes/` 下建立对应变更；不允许只改代码、README 或配置而不留 OpenSpec 记录。

### 强制清单

1. 变更目录使用 `openspec/changes/<change-id>/`，`change-id` 用动词开头的英文短横线命名，例如 `add-readme-feature-screenshots`。
2. 每个变更至少包含 `proposal.md`，写明 Why、What Changes、Capabilities、Impact 与非目标。
3. 涉及实现方案时写 `design.md`；涉及多步执行时写 `tasks.md`，任务要可勾选。
4. 涉及能力行为变化时，在 `specs/<capability>/spec.md` 写 delta；归档后同步到 `openspec/specs/<capability>/spec.md`。
5. 交付完成后归档到 `openspec/changes/archive/YYYY-MM-DD-<change-id>/`，不能长期留在活动变更目录。
6. 提交说明必须引用 `change-id`；无用户可见入口时按 R0 写明。
7. `README`、`Docs/archive` 的需求记录必须能反向链接到对应 OpenSpec 变更。

### 不需要建变更的情况

- 纯错别字、纯格式化、纯依赖升级且不改变行为和文档结构：可以不建变更，但提交说明要写明「无行为变化」。
- 只要改变功能、接口、权限、用户可见结果、文档结构或截图资产范围，就必须建 OpenSpec 变更。

### 反例

- 需求直接改代码，事后才补 OpenSpec → 不合格。
- 只建 `proposal.md`，没有能力 delta 就归档 → 不合格。
- 归档后没有同步 `openspec/specs/` → 不合格。
