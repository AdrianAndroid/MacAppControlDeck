## ADDED Requirements

### Requirement: 多桌宠标签选择
设置 SHALL 提供可扩展标签切换 BongoCat 与 KeyCat，保存选择并立即切换窗口；旧配置迁移为 BongoCat。

#### Scenario: 切换桌宠
- **WHEN** 用户选择 KeyCat 标签
- **THEN** 窗口显示 KeyCat，键鼠事件驱动动画，重启后仍使用 KeyCat。

### Requirement: KeyCat 动画与交互
KeyCat SHALL 使用本地场景资源，按原有比例透明渲染，支持真实键鼠动作、轮廓穿透、按住头部摸头及拖动，并随隐藏或切换释放资源。

#### Scenario: 摸头和拖动
- **WHEN** 用户按住 KeyCat 头部或拖动身体
- **THEN** 分别触发摸头动作或移动浮窗；透明区域不拦截点击。

#### Scenario: 输入监听中断

- **WHEN** 系统禁用并恢复输入监听
- **THEN** 两套桌宠均清除已按下的键鼠状态，不残留按键或爪子动作

## REMOVED Requirements

### Requirement: 皮肤与换肤
**Reason**: 用户改为在 BongoCat 与 KeyCat 之间通过标签选择桌宠，旧皮肤不再作为用户可见选项。
**Migration**: 没有新选择的旧配置默认使用 BongoCat。
