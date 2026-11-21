# 万年历附加模块（2026-11-21）

对应 OpenSpec 变更：[`add-chinese-calendar`](../../../openspec/changes/archive/2026-11-21-add-chinese-calendar/proposal.md)
能力规格：[`calendar-window`](../../../openspec/specs/calendar-window/spec.md)

## 需求

用户希望增加一个中国万年历，视觉参考百度日历，但明确要求：

- 保持现有菜单栏图标点击后弹出 `NSMenu` 下拉框的交互；
- 日历只是下拉菜单里的附加功能，不把状态栏变成日历；
- 默认打开窗口才加载，关闭窗口释放，不长期占用内存；
- 只有「电脑控制」与「截图与录屏」常驻；
- 设置里提供「常驻内存」开关。

## 实现

### 入口

- 菜单栏下拉新增「万年历」子菜单：
  - 今天公历/农历摘要；
  - 宜忌摘要；
  - 下一个节假日倒计时；
  - 「打开万年历…」与「万年历设置…」。
- 新增内置操作 `calendar.open`，并首次播种默认快捷按钮「万年历」，同时出现在菜单栏快捷操作和手机面板。

### 窗口

- 独立 `NSWindow`，默认 720×800，最小 660×720，可缩放并自动记忆位置。
- 7 列月历，默认周一开头，可在设置切换周日开头。
- 日期格：公历大数字、农历/节气/节日小字、周末红字、今天蓝色描边、法定节假日 `休/班` 角标。
- 底部详情：公历/星期、农历、干支/生肖、宜忌、下一个节假日倒计时。

### 生命周期

```text
CalendarModule（轻量代理，长期存在）
└── runtime: CalendarRuntime?
      ├── CalendarStore（42 天月历 + 选中日期）
      └── CalendarWindowController（NSWindow + SwiftUI 视图树）
```

- 默认 `resident=false`：`start()` 不创建 runtime；打开窗口才创建；关闭窗口后释放 runtime。
- `resident=true`：启动时预创建 runtime；关闭窗口只销毁窗口，保留 `CalendarStore`。
- 设置里关闭常驻且窗口已关闭时，立即释放 runtime。

### 依赖

- `6tail/lunar-swift` `1.1.9`（LunarSwift，MIT），仅用于历法数据。
- 不联网、不接 EventKit、不申请定位/通讯录/相册权限。

## 验证

- `swift build` 通过。
- `swift test`：56 个测试全部通过，其中 4 个日历测试：
  - 2026-11-21 → 农历十月十三、丙午年、马；
  - 42 个日期格、当前月 30 天；
  - 2026-10-01 → 国庆节、`休`；
  - 节假日倒计时非空。
- `./Build/build.sh` 构建、签名通过，覆盖安装到 `/Applications/MacAppControlDeck.app`。
- 实机菜单显示：
  - `今天 11月21日 星期六 · 十月十三`
  - `宜 解除 修饰垣墙 冠笄 出行 · 忌 开市 动土 破土 嫁娶`
  - `距离 2027年元旦 还有 41 天`
- 窗口截图：`Docs/images/readme/calendar-window.png`。
- 设置页截图：`Docs/images/readme/settings-calendar.png`。
- 内存验证：
  - `resident=false` 打开再关闭后，`heap --addresses=CalendarStore` 无实例；
  - `resident=true` 关闭窗口后，仍有 1 个 `CalendarStore`；
  - 关闭常驻开关后，实例归零。

## 已知限制

- LunarSwift 法定节假日数据按年维护，当前覆盖到 2027 年；升级依赖后需要回归新年度。
- 不显示用户日程、天气、热搜与百度品牌元素。
- 关闭窗口后业务对象可回收，但进程 RSS 不一定立即下降，这是 AppKit/SwiftUI 框架缓存与分配器行为。
EOF