# 技术设计：万年历附加模块

## 1. 与现有菜单的关系

保持 `MenuBarController` 的原生 `NSMenu` 形态不变：

- 状态栏图标、点击行为、模块排序、置顶命令全部不变；
- `CalendarModule.menuItems()` 只返回一个 `万年历` 子菜单；
- 不在 `NSMenu` 内嵌自定义 `NSView`，避免破坏键盘导航、深色模式和菜单定制。

菜单结构：

```text
万年历
  今天 11月21日 星期六 · 十月十三
  宜 出行 打扫 · 忌 结婚 开业
  距离 2027 年元旦还有 41 天
  ─────────
  打开万年历…
```

前三条为 disabled 摘要项，只读展示；最后一条打开独立窗口。

## 2. 懒加载与释放

### 2.1 结构

```text
CalendarModule（常驻代理，轻量）
├── menuItems()：不创建窗口
├── settingsView()：只读偏好
├── open()：确保 CalendarRuntime
└── runtime: CalendarRuntime?
        ├── CalendarWindowController
        └── CalendarStore
```

`CalendarModule` 是 `FeatureModule`，会被 `ModuleRegistry` 长期持有，但它只保存可选 runtime 和少量字符串，不保存日历数据、窗口或视图。

### 2.2 生命周期

```text
点击“打开万年历…”
→ CalendarModule.ensureRuntime()
→ 创建 CalendarStore + CalendarWindowController
→ show()

关闭窗口
→ windowWillClose
→ 如果 resident=false：CalendarModule.releaseRuntime()
→ controller.shutdown()
→ runtime=nil
```

`CalendarWindowController` 不是单例，由 `CalendarRuntime` 持有。窗口关闭时同时置空：

- `window.delegate`
- `window.contentViewController`
- `window`
- `onClose` 回调（由 module 清理）

### 2.3 常驻内存

`CalendarPreferences.resident` 默认 `false`。

- `resident=false`：`start()` 不创建 runtime；关闭窗口立即释放。
- `resident=true`：`start()` 预创建 runtime；关闭窗口只销毁窗口，保留 `CalendarStore` 与窗口控制器。
- 在设置里关闭 `resident` 时：
  - 窗口已关闭：立即释放 runtime；
  - 窗口仍打开：等 `windowWillClose` 后释放。
- 核心模块 `remote` / `capture` 仍按现有方式常驻，不受本次改动影响。

### 2.4 可释放边界

会释放：

- 日历窗口与 SwiftUI 视图树；
- `CalendarStore`、42 天 `CalendarDay` 数组；
- LunarSwift 计算产生的临时对象；
- 窗口代理与关闭回调。

不会保证立即下降：

- AppKit / SwiftUI 框架缓存；
- Swift runtime 与 malloc 空闲页；
- LunarSwift 类型元数据。

验收标准是反复打开/关闭后对象不累积、内存不持续上涨，而不是关闭瞬间 RSS 必须下降。

## 3. 数据层

使用 `6tail/lunar-swift`（LunarSwift）：

- `Lunar.fromDate(date)` 获取农历、干支、生肖、节气、节日、宜忌；
- `Solar.festivals` / `Lunar.festivals` 获取公历与农历节日；
- `HolidayUtil.getHolidayByYmd` 获取法定节假日与调休；
- `HolidayUtil.getHolidaysByYear` 计算下一个节假日倒计时。

`CalendarDay` 为纯值类型，包含：

- 公历年月日；
- 农历短文本与完整文本；
- 节气/节日/农历日副标题及颜色类型；
- `休/班` 角标；
- 今日、周末、是否当前月；
- 干支、生肖、宜忌。

`CalendarStore` 只负责当前月 42 个日期格与选中日期详情，不注册全局缓存。

## 4. 窗口与视觉

- 独立 `NSWindow`，默认 720×800，可缩放，最小 660×720；
- 顶部年月、前后月、今天；
- 周一/周日起始可配置，默认周一；
- 7 列日期格；
- 底部选中日期详情与节假日倒计时；
- 浅色为主，跟随系统深色模式；
- 不使用百度品牌元素。

## 5. 已知限制

- LunarSwift 的法定节假日数据由上游按年维护，当前 v1.1.9 覆盖到 2027 年；
- 不接入 EventKit，因此不显示用户日程；
- 不联网，因此没有天气、定位、热搜；
- 关闭窗口后 runtime 释放，但进程 RSS 可能因框架缓存不立即下降。
