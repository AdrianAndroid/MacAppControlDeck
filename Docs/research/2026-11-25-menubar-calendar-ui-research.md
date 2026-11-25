# 菜单栏日历下拉：现成开源项目调研（只调研，未改代码）

日期：2026-11-25
目标：把现在「万年历」状态项只有 3 行纯文字的下拉，换成像 LunarBar / Calendr 那样成熟的日历面板；先从 GitHub 找可复用项目，评估 License、平台、依赖和可集成性。

---

## 1. 现状诊断（为什么显得 demo）

- 状态栏「万年历」入口在 `Sources/MacAppControlDeck/Modules/Calendar/CalendarModule.swift` 的 `menuItems()`：一个父菜单 + `今天 …` / `宜 … 忌 …` / 倒数日 3 行 **纯文字** + 「打开万年历…」「万年历设置…」。没有月历网格。
- 独立窗口 `CalendarWindowView.swift` 其实是**完整的 720×800 SwiftUI 月历**：农历、节气、宜忌、干支、节假日徽标都在，`6tail/lunar-swift` 数据层已经很成熟。所以缺的是「把月历塞进下拉」，不是重做数据层。
- 状态栏架构（`Core/StatusBar/StatusBarRegistry.swift` + `StatusBarEntry.swift`）：一个条目一条独立 `NSStatusItem`，`activate(from view:)` 明确允许「弹菜单 / 打开窗口 / 走深链接」，可以扩展成弹 `NSPopover`。
- 现有 CPU/MEM/网速下拉用 `NSMenuItem.view` 塞自绘 `NSView`（见 `SystemToolStatusMenus.swift`），证明嵌自定义视图可行；但日历需要**持续交互**（翻月、选日），`NSPopover` + `NSHostingController` 比 `NSMenu` 更稳。

结论：数据层复用现有 `lunar-swift`，UI 网格和面板交互借开源项目，承载方式用新状态项 + `NSPopover`。

---

## 2. 候选清单（GitHub API 实测，2026-11-25）

| 项目 | Stars | License | 最近提交 | 平台 / 形态 | 能直接用？ | 结论 |
| --- | ---: | --- | --- | --- | --- | --- |
| **Mijick/CalendarView** | 578 | MIT | 2025-09 发布 1.1.1 | macOS 11+，SwiftPM library，零依赖 | ✅ 直接加 | **网格引擎首选**：`.dayView(...)` 可完全自定义日期格，把农历/徽标塞进去 |
| **iletai/SwiftUICalendarView** | 133 | MIT | 2026-11-05 | macOS 13+，SwiftPM library `CalendarView`，零依赖 | ✅ 直接加 | 备选：固定 42 格矩阵、月/周/年、滑动手势；自定义日格能力需再确认 |
| **mazefest/MooCal** | 53 | Apache-2.0 | 2026-03 | SwiftPM library，轻量 SwiftUI 日历 | ⚠️ 可用 | 备选，Apache-2.0 声明成本略高 |
| **LunarBar-app/LunarBar** | 1526 | MIT | 2026-11-09 | macOS 26+，Xcode 工程；`LunarBarKit` 是 SwiftPM 库但要求 macOS 26 / Swift 6.4、本地路径依赖 + SwiftLint 插件、含 `unsafeFlags` | ❌ 不能依赖 | **视觉参考首选**：极简农历面板，精致度最高；只借鉴设计，不复制代码 |
| **pakerwreah/Calendr** | 2461 | MIT | 2026-11-23 | macOS 15+，SwiftPM **executable**+RxSwift/Sentry 等 6 依赖 | ❌ 不能依赖 | **交互参考首选**：月历 + 周数 + 事件圆点 + 日程列表；只借鉴设计 |
| bylinxx/MacCalendar | 879 | **无 License** | 2026-11-02 | SwiftUI App，农历/节气/调休/小组件/EventKit | ❌ 不可复用 | 功能最全但**无授权 = 默认保留所有权利**，只能看功能清单 |
| daodao97/TinyCal | 62 | **无 License** | 2026-08-19 | SwiftUI + AppKit `NSStatusItem`+`NSPopover` | ❌ 不可复用 | 架构思路可参考，代码不能用 |
| dayedge/dayedge | 4 | MPL-2.0 | 2026-11-20 | 菜单栏日历 + 提醒 | ⚠️ | 文件级 copyleft，不推荐 |
| lifuyi/calendar | 0 | **无 License** | 2026-11-13 | 搜索结果来自镜像站，真实仓库 0★ | ❌ | 排除 |
| zjinhu/LunarCalendar-SwiftUI | 32 | MIT | 2021-03 | 农历 SwiftUI 日历 | ⚠️ | 停更 5 年，且我们已有 lunar-swift |
| 6tail/lunar-swift | 159 | MIT | 2026-11-06 | 农历/节气/宜忌数据库 | ✅ **已在用** | 继续作为数据层，不重复引入 |

被排除的高星组件：`ThasianX/ElegantCalendar`(1095★, 2023 停更)、`RaffiKian/RKCalendar`(584★, iOS)、`GGJJack/SwiftUICalendar`(254★, iOS only)、`yodagamaheshan/DateGrid`(201★, 无 License 且代码 2022 停更)。

---

## 3. 视觉参考要点（看截图得到的，不是我脑补）

**LunarBar**（`Screenshots/01.png` / `02.png`）
- 毛玻璃圆角面板，顶部有小三角指向菜单栏状态项。
- 日期格两行：大号公历数字 + 小号农历/节气；今天用圆形描边；节日用彩色书签小旗；格底 1~3 个彩色小圆点表示当天事件/提醒。
- 非本月日期降透明度；周末/节假日数字变色；顶部工具栏只有翻月箭头 + 今日圆点 + 少数图标，克制。
- 右键菜单样式统一（今天 / 跳转至月份 / 外观 / 日历 / 公共假日 / 登录时启动 …）。

**Calendr**（`resources/screenshot.png`）
- 面板分两段：上半月历网格（左侧周数 53/1/2…，事件用圆点）、下半**当天日程列表**（彩色竖条 + 时间 + 标题 + 时长），工具栏一排图标。
- 成熟点在于「网格 → 详情」的信息层级，以及日期有事件时的视觉反馈，不是单纯画格子。

---

## 4. 推荐方案（组合，不重复造轮子）

1. **数据层**：继续用现有 `6tail/lunar-swift`（农历、节气、宜忌、干支、节假日）。零新增依赖。
2. **网格引擎**：加 `Mijick/CalendarView` 作为 SwiftPM 依赖（`macOS 11+`、零依赖、MIT），用它的 `.dayView(...)` 自定义日期格，渲染我们已有的农历/节气/节假日徽标。
3. **承载**：新增一个状态项条目（如 `calendar.panel`），菜单栏**只显示一个日历图标**（用户明确要求：不显示日期文字、宽度固定），`activate(from:)` 弹 `NSPopover`，内部 `NSHostingController` 装 SwiftUI 月历面板；点面板外自动关闭，保留「打开完整万年历…」入口。
4. **视觉**：按 LunarBar 的两行日期格 + 今日描边 + 节日书签，按 Calendr 的「网格 + 当天详情」分层；不复制它们的代码，只按截图做自己的实现。

### ASCII 草图（最终形态：深色玻璃月历卡片复刻）

```
菜单栏:       📅
                ▲   ← NSPopover 小箭头指向状态项
        ┌────────────────────────────────────────┐
        │                                        │
        │  2025年10月              ‹   ○   ›  ⋯   │
        │                                        │
        │   日    一    二    三    四    五    六    │
        │                                        │
        │   28    29    30     1     2     3     4   │
        │  初七   初八   初九   初十  十一  十二  十三 │
        │   ▍     ·           ▍    ▍    ▍    ▍      │
        │                                        │
        │    5   ╭──╮   7     8     9    10    11   │
        │  十四  │ 6 │ 初七   寒露  十八  十九  二十 │
        │       │中秋│                         ▍   │
        │       ╰──╯                              │
        │                                        │
        │   12    13    14    15    16    17    18   │
        │  廿一   廿二   廿三   廿四   廿五   廿六  廿七 │
        │                                        │
        └────────────────────────────────────────┘
```

深色毛玻璃卡片 + 16pt 圆角 + 1px 亮边；大号月份标题、`‹ ○ ›` 翻月/今天控件、`⋯` 更多菜单（完整万年历 / 设置）；周日首列、邻月日期淡显、今日蓝色描边、农历/节气小字；彩色圆点与书签**只由农历/节气/节日/休班数据驱动**，不读取 EventKit、不代表用户日程。

---

## 5. 风险与注意事项

- **别引 LunarBarKit**：它要求 macOS 26 + Swift-tools 6.4，本项目是 macOS 14 / Swift 6.2.4，且它带 `../LunarBarTools` 本地路径依赖、SwiftLint 插件和 `unsafeFlags`，强引会破坏现有构建/发版链。
- **别引 MacCalendar / TinyCal**：仓库无 License，法律上默认不可复用。LunarBar / Calendr 是 MIT，但作为 App 形态，参考设计可以，复制代码要保留版权声明。
- **License 声明**：若最终引入 Mijick/CalendarView，需在 `THIRD_PARTY_NOTICES.md` 增加 MIT 声明。
- **交互验证**：`NSPopover` 内的 SwiftUI 日期点击、翻月、面板外点击关闭、与现有三个状态项的排位，都要真机验证；`NSMenu` 嵌网格虽然可行但交互体验差，不推荐。
- **图标形态**：状态项只显示一个 `calendar` SF Symbol，宽度固定、不随日期文字变化；沿用 `StatusBarItemControl` 的 `variableLength` + 自定义 `NSView`，需真机确认图标不与相邻状态项挤在一起。
- **权限**：只读 lunar-swift 数据，不读 EventKit 日程（避免新增 TCC 授权）；事件圆点如需显示，后续再单独评估 EventKit 权限。
- **版本**：新下拉属于用户可见功能，按项目 OpenSpec 约定需要先建 change，完成后更新 `system-cleaner` / 新增 `status-bar` 相关规格与版本记录。

---

## 6. 下一步（等你确认，本次没动代码）

- 选项 A（推荐）：`Mijick/CalendarView` 做网格 + 现有 lunar-swift 数据 + `NSPopover` 下拉，按 LunarBar/Calendr 视觉实现。
- 选项 B：`iletai/SwiftUICalendarView` 做网格（需先确认自定义日格能力）。
- 选项 C：不引第三方库，直接照 LunarBar 视觉在现有 SwiftUI 里自绘（零依赖，但工作量大、动画/手势要自己做）。

确认选项后再进入 OpenSpec change → 实现 → 测试 → 构建覆盖安装。
