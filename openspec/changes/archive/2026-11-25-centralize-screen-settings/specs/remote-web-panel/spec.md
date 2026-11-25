## ADDED Requirements

### Requirement: Mac 端统一副屏显示配置

Mac 端 SHALL 提供 `ScreenDisplaySettings`，统一维护副屏尺寸、桌宠模式/宠物/随机间隔、屏幕常亮与换宠计数，并通过只读 API 下发给所有副屏页面；副屏页面 MUST NOT 提供这些选项的设置入口，也 MUST NOT 把它们写入 `localStorage`。

#### Scenario: Mac 端修改配置立即下发

- **WHEN** 用户在 Mac「设置 → 副屏 → 副屏显示与桌宠」修改任一选项
- **THEN** 配置写入 Mac `UserDefaults`，并通过屏幕刷新事件通知所有副屏
- **AND** 副屏收到事件后重新拉取 `/api/screen/display` 并应用
- **AND** 副屏本地不残留 `deck_screen_size` 或 `deck.screen.pet.*` 等键

#### Scenario: 配置字段与归一化

- **WHEN** 副屏请求 `GET /api/screen/display`
- **THEN** 返回 `size` / `petMode` / `petId` / `petInterval` / `keepAwake` / `petSwitchNonce`
- **AND** 非法值被归一化为 `m` / `fixed` / `cat` / `60`
- **AND** 响应不带凭据、坐标或其他隐私字段

#### Scenario: 从 Mac 端立即换宠

- **WHEN** 用户在 Mac 端点「立即换一只」
- **THEN** 固定模式下 `petId` 前进到下一只宠物
- **AND** 随机模式下 `petSwitchNonce` 递增，副屏据此重置队列并换宠

## MODIFIED Requirements

### Requirement: 副屏控制条

副屏控制条 SHALL 只保留「强制刷新」按钮，以及浏览器支持全屏时的「全屏」按钮；尺寸切换、桌宠设置入口与常亮状态文字 MUST NOT 出现在副屏页面。

#### Scenario: 控制条按钮

- **WHEN** 用户点按屏幕唤出控制条
- **THEN** 控制条仅含 `↻` 刷新按钮与（支持时）`全屏` 按钮
- **AND** 不出现 `小/中/大` 尺寸按钮、`⚙` 桌宠设置按钮、常亮状态文字

#### Scenario: 强制刷新

- **WHEN** 用户点「↻」
- **THEN** 页面重新拉取 Mac 时间、天气、倒计时、外观设置与显示配置，不整页重载
- **AND** 刷新期间按钮显示忙态，完成后短暂显示「已刷新」，控制条保持可见

### Requirement: 尺寸与常亮

副屏 SHALL 按 Mac 端下发的尺寸档位缩放；常亮开关由 Mac 端控制，副屏不再显示常亮状态文字。

#### Scenario: 三档尺寸

- **WHEN** Mac 端设置尺寸为小/中/大
- **THEN** 副屏字号、间距与圆角按对应比例立即缩放
- **AND** 尺寸仅由 Mac 配置决定，副屏本地不保存

#### Scenario: 屏幕常亮

- **WHEN** Mac 端开启常亮且浏览器支持 Wake Lock
- **THEN** 副屏申请屏幕常亮，并在回到前台时重新申请
- **AND** Mac 端关闭常亮时释放 Wake Lock
- **AND** 副屏不显示常亮状态文字，不谎报已开启
- **AND** 支持全屏的浏览器显示全屏按钮，WKWebView / iOS Safari 不显示

### Requirement: 副屏桌宠底栏

横屏副屏 SHALL 在时钟下方显示固定高度的桌宠框，桌宠在框内左右游走；模式与间隔完全由 Mac 端下发，副屏 MUST NOT 提供设置入口。

#### Scenario: 桌宠游走

- **WHEN** 横屏且页面可见、系统未开启减弱动态效果
- **THEN** 当前桌宠在框内左右游走，碰到边界自动掉头
- **AND** 切换宠物不扩大或缩小桌宠框
- **AND** 页面隐藏时暂停游走，恢复可见后继续

#### Scenario: 换宠设置由 Mac 端提供

- **WHEN** 用户在 Mac 端切换固定/随机模式、选择宠物或随机间隔
- **THEN** 配置下发后副屏立即应用
- **AND** 随机模式按洗牌队列切换，避免连续重复
- **AND** 普通刷新不打断当前随机轮播
