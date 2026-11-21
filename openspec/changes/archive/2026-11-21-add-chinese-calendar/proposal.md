# 提案：万年历附加模块

## Why

当前菜单栏下拉框只提供电脑控制、截图与 UI 草图。用户希望增加一个中国万年历作为附加功能，但明确要求：

- 不改变现在点击菜单栏图标弹出下拉菜单的交互；
- 日历不要常驻内存，只有打开时才加载；
- 关闭日历窗口后释放日历模块，避免长期占用；
- 视觉参考百度日历的月历、农历、节气、节日、宜忌和节假日倒计时。

因此本次新增一个可懒加载、可释放的 `calendar` 模块，而不是替换现有 `NSMenu` 或新增状态栏图标。

## What Changes

- 新增 `calendar` 功能模块，菜单中只增加一个「万年历」子菜单：
  - 今日摘要（公历、农历、宜忌、节假日倒计时）；
  - 「打开万年历…」动作。
- 新增独立 `NSWindow` 日历窗口，默认 720×800：
  - 7 列月历，周一/周日起始可配置；
  - 公历大数字 + 农历小字 + 节气/节日彩色小字；
  - 法定节假日 `休/班` 角标；
  - 选中日期详情、宜忌、下一个节假日倒计时；
  - 不包含百度搜索框、频道 Tab、热搜、广告、天气与定位。
- 新增 `CalendarModule` 轻量代理与 `CalendarRuntime`：
  - 默认不常驻；
  - 首次打开时创建窗口、ViewStore 与 LunarSwift 数据；
  - 关闭窗口后销毁窗口、ViewStore 与 runtime；
  - 设置中提供「常驻内存」开关；开启后保留 runtime，关闭后立即释放空闲 runtime。
- 接入 `6tail/lunar-swift`（LunarSwift，MIT），只作为历法数据依赖，不引入其 UI。
- 新增内置操作 `calendar.open`，并在默认快捷按钮中播种一次「万年历」入口，满足 R0。
- 在设置中新增「万年历」页，提供常驻内存与周起始日设置。

**非目标**：

- 不把日历嵌入 `NSMenu` 的菜单项视图。
- 不新增第二个菜单栏状态项，不改变现有状态栏图标。
- 不接入系统日历 EventKit、天气、定位、网络请求。
- 不复制百度品牌、图标、搜索框或页面资源。
- 不在第一版实现日程编辑、提醒、节假日筛选。

## Capabilities

### New Capabilities

- `calendar-window`：菜单入口、独立日历窗口、农历/节气/节日/宜忌/节假日倒计时、懒加载与关闭释放、常驻内存开关。

### Modified Capabilities

- 无。

## Impact

- 代码：
  - `Package.swift`：新增 LunarSwift 依赖。
  - `Sources/MacAppControlDeck/Modules/Calendar/`：新增模块、数据、窗口和视图。
  - `Sources/MacAppControlDeck/App/DeckApp.swift`：注册 `CalendarModule`。
  - `Sources/MacAppControlDeck/Control/BuiltinActions.swift`：新增 `calendar.open`。
  - `Sources/MacAppControlDeck/Store/ConfigStore.swift`：播种默认「万年历」快捷按钮。
  - `Sources/MacAppControlDeck/UI/SettingsView.swift`：新增日历设置页与模块常驻开关。
- 文档：`README.md`、`THIRD_PARTY_NOTICES.md`、`Docs/archive/2026-11-21-chinese-calendar/SUMMARY.md`。
- 测试：新增 `CalendarStoreTests`；全量 `swift test` 回归。
- 权限/API/数据：无新增系统权限；LunarSwift 纯本地计算；不联网。
- 用户可见入口：菜单「万年历」、内置操作 `calendar.open`、默认快捷按钮「万年历」。
- 已知限制：LunarSwift 的法定节假日数据按年更新；未来年份需要升级依赖或补充数据。
