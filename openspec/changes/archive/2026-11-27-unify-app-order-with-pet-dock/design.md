# 设计：手机主屏应用顺序与桌宠快捷栏统一

## 1. 现状

| 面 | 顺序来源 | 点击统计 | 重排时机 |
| --- | --- | --- | --- |
| 桌宠快捷栏 | `PetDockView.refreshOrder()` 本地排序 `DeckState.appButtons` | `PetDockStats.record()`（只在桌宠点击时） | 点击后 5 秒 `DispatchWorkItem` |
| 手机主屏 | `ConfigStore.sortedButtons()`（仅 `kind` + `sortOrder`）经 `GET /api/buttons` | 无 | 手动排序变化后，2 秒轮询自然刷新 |

排序公式已经存在，不需要新算法：

```text
frequency = Σ 0.5^(age / halfLife)     // halfLife 默认 7 天
            冷却期内（默认 30 分钟）再 ×0.4
recent    = 最后一次点击时间降序
manual    = ConfigStore 的 sortOrder
同分      = 保持当前配置顺序
```

问题不是公式，而是**统计与排序只在桌宠本地存在**，手机拿不到、也写不进去。

## 2. 目标数据流

```text
                        ┌────────────────────┐
 手机点击 ──► APIRouter │ AppDockOrdering    │ ◄── 桌宠点击
 桌宠点击 ──► DeckState │  · stats           │
                        │  · mode            │
                        │  · orderedIDs      │
                        │  · 5s debounce     │
                        └─────────┬──────────┘
                                  │ ordered apps
                ┌─────────────────┴─────────────────┐
                ▼                                   ▼
        GET /api/buttons                     PetDockView
        （应用按共享顺序下发）               （直接读共享顺序）
```

- **唯一写入点**：任何「应用」按钮被点击时调用 `AppDockOrdering.recordClick(bundleID:)`。
- **唯一读取点**：桌宠与 `/api/buttons` 都向 `AppDockOrdering` 要顺序。
- **唯一重排定时器**：在 `AppDockOrdering` 内部，5 秒防抖。

## 3. 共享服务

### 3.1 类型拆分

建议放在 `Sources/MacAppControlDeck/Modules/AppDock/`：

```swift
@MainActor final class AppDockSettings: ObservableObject {
    // 沿用现有键：pet.dock.sort / cooldownMinutes / halfLifeDays
    @Published var sortMode: PetDockSortMode   // 可改名 AppDockSortMode
    @Published var cooldownMinutes: Int
    @Published var halfLifeDays: Int
    @Published var enabledDock: Bool            // 仍只控制桌宠快捷栏显示
    @Published var showRunningDot: Bool
    @Published var markLastClicked: Bool
}

@MainActor final class AppDockStats: ObservableObject {
    // 沿用 pet.dock.launchEvents / pet.dock.lastClicked
    @Published private(set) var events: [String: [Double]]
    @Published private(set) var lastClickedID: String?
    func record(bundleID: String)
    func score(...)
    func clearLastClickedIfNotRunning()
    func reset()
}

@MainActor final class AppDockOrdering: ObservableObject {
    @Published private(set) var orderedAppIDs: [String]
    @Published private(set) var revision: Int
    func orderedApps(from apps: [ButtonConfig]) -> [ButtonConfig]
    func recordClick(bundleID: String)
    func resortNow()          // 设置变化 / 应用增删时立即重算
}
```

兼容策略：

- `PetDockSettings` / `PetDockStats` 保留为 typealias 或薄包装，避免一次性大面积改名。
- 所有 UserDefaults 键不变，升级后历史点击与设置继续生效。

### 3.2 排序算法

`orderedApps(from:)`：

1. `manual`：按 `sortOrder` / 当前 `ConfigStore` 顺序；
2. `recent`：按 `stats.events[bundleID]?.last` 降序，同分按配置顺序；
3. `frequency`：按 `stats.score(bundleID:)` 降序，同分按配置顺序；
4. 已删除的 ID 自动丢弃；新加入的 ID 追加到末尾（不插入中间，避免位置乱跳）。

`orderedAppIDs` 是快照。应用增删、排序模式变化、5 秒防抖到期时重算；其余时间保持稳定。

### 3.3 5 秒防抖

- `recordClick()`：写统计、更新 `lastClickedID`、取消旧定时器，起一个新的 5 秒 `DispatchWorkItem`。
- 5 秒内再点击只重置计时，不改变当前顺序。
- 到期后 `resortNow()`，`revision += 1`。
- 排序模式切换、应用增删、`/api/buttons` 首次读取时立即重算（不等 5 秒）。
- 防抖定时器全进程唯一；桌宠隐藏、手机断开都不影响它。

### 3.4 与「最近点击」视觉的关系

- 手机点击也更新 `lastClickedID`，桌宠快捷栏对应图标下一帧变浅；
- 应用退出时 `clearLastClickedIfNotRunning()` 继续清理，避免「关了还灰着」；
- 手机本身不展示「最近点击」状态（界面不变）。

## 4. 服务端契约

### 4.1 `GET /api/buttons`

- 应用按钮：按 `AppDockOrdering.orderedApps(from: store.appButtons)` 的顺序返回；
- 快捷操作 / 命令 / 内置：维持现有 `sortedButtons()` 中的非应用顺序；
- 响应结构不变，可额外返回未来可用的 `sortMode` 与 `orderRevision`，旧面板忽略未知字段即可；
- 该端点在应用点击后 **不会** 立刻换序：共享服务在 5 秒防抖到期后才重排，面板 2 秒轮询自然拿到新顺序。

### 4.2 `POST /api/activate`

- 请求仍是 `{ buttonId }`，不新增字段；
- `kind == .app` 时，进入激活流程**之前**调用 `AppDockOrdering.recordClick(bundleID:)`；
- 计数是乐观的：即使随后启动失败，也保留这一次点击（与桌宠当前行为一致）；
- 快捷键 / 命令 / 内置不计数。

## 5. 手机面板行为

- 界面与布局完全不变：应用卡片、图标、名称、2 列 / 4 列、整页翻页、页点、状态行。
- 页面不做任何本地排序；只渲染 `/api/buttons` 给出的顺序。
- 轮询：现有 `setInterval` 每 2 秒在空闲时 `loadButtons()`；5 秒防抖到期后的下一次轮询会换成新顺序。
- 翻页：沿用 `restorePage()`，重排后保持当前页索引；页数不够时夹到最后一页。
- 点击瞬间：按钮位置不变（5 秒后才可能移动），不会在手指下面跳格。
- 若应用在另一台手机上被点击，本机顺序同样在 5 秒后跟随刷新。

## 6. 设置与文案

单一入口保持 设置 → 桌面宠物 →「底部快捷栏」：

- 排序方式：点击频率 / 手动顺序 / 最近使用
- 冷却时间、半衰期
- 说明追加一句：「排序同时作用于桌宠快捷栏与手机面板的应用区。」

不新增设置页，不改手机面板的可见控件。

## 7. 边界与风险

| 场景 | 处理 |
| --- | --- |
| 桌宠模块关闭 / 快捷栏关闭 | 共享服务照常统计与排序，手机仍可自动排序 |
| 手机点击失败 | 仍记录一次点击（乐观计数，与桌宠一致） |
| 重排时正在执行按钮队列 | 手机空闲才轮询，队列执行中保持原顺序；队列结束后再刷新 |
| 应用被删除 | 下次重排时从 `orderedAppIDs` 丢弃；点击返回 404（现有行为） |
| 多台手机同时点击 | 同一份统计；5 秒内连续点击统一防抖 |
| 手动模式 | 仍按 Mac 端按钮管理的顺序，手机与桌宠完全一致 |
| 首次升级 | 读取现有 `pet.dock.*` 数据，不重置用户历史 |

## 8. 实施顺序

1. 抽出 `AppDockSettings` / `AppDockStats` / `AppDockOrdering`，旧类型做兼容包装；补单元测试。
2. 桌宠快捷栏改读共享顺序，删除本地排序与 5 秒定时器；行为应无可感知变化。
3. `/api/buttons` 改用共享顺序；`/api/activate` 记录应用点击。
4. 手机端只 bump `PanelHTML.version`，不加新 UI；验证重排后翻页位置与状态行。
5. 归档前跑相关测试并真机复核两端顺序一致。

## 9. 测试计划

- 单元：
  - `frequency` / `recent` / `manual` 三种模式的顺序与同分规则；
  - 冷却 ×0.4、半衰期衰减；
  - 5 秒防抖：点击后立即读顺序不变，到期后变化（可注入时钟）；
  - 删除 ID 丢弃、新 ID 追加；
  - `lastClickedID` 跨端更新与退出清理。
- 服务端：
  - `GET /api/buttons` 应用顺序等于共享服务；
  - `POST /api/activate` 应用按钮写入一次统计，快捷操作不写；
  - 5 秒前后的两次请求顺序不同。
- 面板：
  - `PanelLayoutTests` / `ScreenHTMLTests` 不回归；
  - 真机：手机点击 → 桌宠对应图标变浅；5 秒后两端顺序一起变化；翻页索引保持。

## 10. 非目标

- 不把手机应用区改成桌宠同款单行图标条。
- 不改手机卡片尺寸、分页容量与快捷操作区。
- 不新增手机端排序切换按钮。
- 不改桌宠快捷栏的拖动、长按提示与视觉。
