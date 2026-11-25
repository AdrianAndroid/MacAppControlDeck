# Tasks: 状态栏日历图标与月历下拉面板

## 1. 依赖与规格

- [x] 1.1 `Package.swift` 新增 `Mijick/CalendarView` exact 1.1.1，`MacAppControlDeck` target 链接 `MijickCalendarView`。
- [x] 1.2 `swift package resolve --disable-sandbox` 解析成功（v1.1.1）。
- [x] 1.3 `THIRD_PARTY_NOTICES.md` 增加 Mijick/CalendarView 的 MIT 声明。

## 2. 状态栏日历图标条目

- [x] 2.1 新建 `CalendarStatusBarEntry.swift`：实现 `StatusBarEntry`，`id = "calendar.panel"`，`order = 3`，`defaultVisible = true`，`isAvailable` 跟随 `CalendarModule` 开关。
- [x] 2.2 `makeView()` 返回只含 SF Symbol `calendar` 的定宽 NSView（不显示日期文字）。
- [x] 2.3 `activate(from:)` 构建并弹出 `NSPopover`（transient、darkAqua、锚定状态项 view、底部箭头）。
- [x] 2.4 `CalendarModule.start()` 注册该条目；设置页「状态栏」自动出现开关（由 `StatusBarRegistry` 统一处理，无需改设置页代码）。

## 3. SwiftUI 下拉面板（复刻锁定屏月历）

- [x] 3.1 新建 `CalendarPopoverView.swift`：336×382 深色玻璃卡片，16pt 圆角 + 亮边；头部大号「2025年10月」+ `‹ ○ › ⋯`。
- [x] 3.2 接入 `MCalendarView`：中文 locale、**周日起始**、±1 年范围、定位今天、月份变化回调；库内月份标题置空。
- [x] 3.3 自定义 `DayView` 并覆盖 `body`：邻月日期淡显、17pt 公历数字、农历/节气小字、今日蓝框、节日/休班彩色圆点与书签；**不读取 EventKit**。
- [x] 3.4 自定义 `WeekdaysView`（日一二三四五六）与空 `MonthLabel`；面板头部统一绘制标题。
- [x] 3.5 「打开完整万年历…」「设置…」收进标题栏 `⋯` 菜单，保持面板纯净。

## 4. 测试与验收

- [x] 4.1 为「今日高亮」「节假日徽标」「农历小字」添加纯数据层测试（不依赖 UI 渲染）。
- [x] 4.2 `swift test --disable-sandbox` 全量通过。
- [x] 4.3 构建签名 .app，覆盖安装到 /Applications。
- [x] 4.4 验证：release 编译 + 签名 + 覆盖安装 + 启动无秒退 + 状态栏截图确认图标未裁切 + DR 仍为 `e8357462…`；面板交互由用户手动点击验收（辅助功能与合成点击受 TCC/菜单栏限制，不绕过权限）。

## 5. 收尾

- [x] 5.1 更新 `Docs/research/2026-11-25-menubar-calendar-ui-research.md` 的最终形态（深色玻璃复刻版）。
- [x] 5.2 归档 change、同步主 spec `status-bar`、README 反向链接。
