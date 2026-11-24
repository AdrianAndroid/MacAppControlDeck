# app-control 变更（fix-slow-app-activation）

## MODIFIED Requirements

### Requirement: 激活已运行的应用并切到前台（含跨桌面空间）

系统 SHALL 采用"等价真人点击 Dock"的激活路径，在具备辅助功能权限时优先通过 Dock 图标 AXPress 完成激活；成功与否以"目标应用是否成为前台应用"为唯一条件，不因进程内窗口列表统计结果为 0 而判失败。

#### Scenario: Dock 中存在多个空标题项

- **WHEN** 辅助功能遍历 Dock 子项时遇到标题为空或归一化后为空的项（如分隔符、空格图标）
- **THEN** 系统跳过该项，不把它当作目标应用的图标按下
- **AND** 只有标题与目标应用名匹配的非空 Dock 项才会执行 AXPress

#### Scenario: 前台已切换但进程内可见窗口为 0

- **WHEN** 目标应用已成为 `NSWorkspace.frontmostApplication`，但 `CGWindowListCopyWindowInfo` 统计的可见窗口数为 0（窗口在其他桌面空间或有缓存偏差）
- **THEN** 系统判定激活成功并返回"已切换到前台"
- **AND** 不继续尝试后续弱兜底策略，不返回"未能切前台"

#### Scenario: 激活失败时快速收敛

- **WHEN** 各级激活策略均未让目标应用成为前台
- **THEN** 每条策略的等待上限不超过 2 秒，全部策略在 10 秒内收敛并返回真实失败原因
- **AND** 成功路径的响应时间不受失败等待上限影响
