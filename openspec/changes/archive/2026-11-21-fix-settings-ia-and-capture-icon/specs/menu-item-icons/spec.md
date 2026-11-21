# menu-item-icons 规格

## ADDED Requirements

### Requirement: 菜单项图标必须有效

需要图标的菜单项 SHALL 使用当前系统可解析的 SF Symbol；不得使用返回 nil 的无效符号导致菜单项空白。

#### Scenario: 区域截图菜单

- **WHEN** 用户展开「截图与录屏 → 区域截图」
- **THEN** 菜单项显示有效图标
- **AND** 该命令被置顶到菜单栏快捷操作时，置顶项同样显示图标
