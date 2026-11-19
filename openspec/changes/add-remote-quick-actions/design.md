# 技术设计：远程快捷操作（add-remote-quick-actions）

## 1. 数据模型

### 1.1 按钮模型 v2

`ButtonConfig` 从"只描述应用"扩展为带类型的联合体（保持扁平 JSON，便于迁移与宽容解析）：

```jsonc
// 应用按钮（与现状兼容）
{
  "id": "UUID",
  "kind": "app",              // 新增；缺失时按 "app" 处理
  "name": "DevEco Studio",
  "bundleID": "com.huawei.devecostudio.ds",
  "appPath": "/Applications/DevEco-Studio.app",
  "sortOrder": 0
}

// 快捷操作按钮
{
  "id": "UUID",
  "kind": "shortcut",         // 新增
  "name": "复制",              // 用户可改名，默认取组合符号
  "sortOrder": 0,
  "shortcut": {
    "modifiers": ["command"], // command | control | option | shift | function
    "keyCode": 8,             // macOS virtual keycode（与键盘布局无关）
    "keyLabel": "C"           // 展示用主键名称（F1/→/C 等）
  }
}
```

设计取舍：

- **扁平 + 可选字段**：不引入 Codable 多态（enum 关联值）以免旧数据解析失败；`kind` 缺失 → `app`；`shortcut` 缺失时该按钮不可触发并给配置错误提示。
- **virtual keycode 而非字符**：字符受键盘布局与输入法影响，键码稳定；展示用 `keyLabel` 单独保存。
- **修饰键数组**：可录制/拼凑任意组合；顺序无关，写入前归一化排序。

### 1.2 迁移策略

- 解码：`kind` 默认 `.app`，未知字段忽略但不丢弃（保留原始字典后写回的场景不涉及——MVP 采用整体重编码，未知字段丢失属可接受，记录在差异说明中；如需严格保留则改用字典存储，暂不引入）。
- 写入：始终输出 v2 结构；`sortOrder` 保持全局连续，分组展示按 `kind` 再按 `sortOrder` 排序。
- 文件版本：不新增版本号字段，靠 `kind` 缺省实现向前兼容。

## 2. 执行架构

```
POST /api/activate {buttonId}
        │
        ▼
APIRouter ── 按钮查找（白名单）──┬─ kind == app      → AppControl.activate(bundleID)
                              └─ kind == shortcut → KeyInjector.inject(combo)
                                                     ├─ 权限检查 AXIsProcessTrusted
                                                     ├─ 安全输入检查 IsSecureEventInputEnabled
                                                     └─ CGEvent 注入（down/up + flags）
```

- 新增 `KeyInjector`（与 `AppControl` 平行的执行器），接受**已解析的组合**，不接触任何外部字符串。
- `AppControlling` 协议保持不变；新增 `ShortcutInjecting` 协议便于测试替身。
- 路由只接受按钮 ID，按键组合只能来自本机配置，杜绝任意按键注入。

## 3. 预设与键码映射

| 预设 | 修饰键 | keyCode | 展示 |
| --- | --- | --- | --- |
| 桌面左 | control | 123 (←) | ⌃← |
| 桌面右 | control | 124 (→) | ⌃→ |
| 复制 | command | 8 (C) | ⌘C |
| 粘贴 | command | 9 (V) | ⌘V |
| 全选 | command | 0 (A) | ⌘A |
| 撤销 | command | 6 (Z) | ⌘Z |
| 回车 | — | 36 | ↩ |
| Esc | — | 53 | ⎋ |
| F1–F12 | — | 122,120,99,118,96,97,98,100,101,109,103,111 | F1…F12 |

- 键码为 ANSI 虚拟键码，与布局无关；`keyLabel` 仅用于展示。
- 预设在代码中作为常量表存在，Mac UI 与测试共用；不写入配置文件（配置只存实际组合）。

## 4. 注入实现细节

```swift
// 伪代码
guard AXIsProcessTrusted() else { return .accessibilityRequired }
guard !IsSecureEventInputEnabled() else { return .secureInput }

let flags: CGEventFlags = combo.modifiers.cgFlags
for event in [down, up] {
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(60_000)
}
return .sent
```

- **注入源**：`CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown:)` + `.cghidEventTap`（本机实测可被前台应用接收：复制/粘贴链路验证通过）。
- **修饰键**：通过 `event.flags` 设置（`.maskCommand/.maskControl/.maskAlternate/.maskShift/.maskSecondaryFn`）。
- **Down/Up 间隔** 60ms，避免部分应用的组合键识别失败；不做长按连发。
- **安全输入检查**：Carbon `IsSecureEventInputEnabled()`（密码框/锁屏会返回 true），为 true 时直接返回 `secure-input`，不注入。
- **无法确认应用是否响应**：注入成功只代表事件已发出，响应为 `sent`，不承诺结果。
- **不模拟文本输入**：本变更不做文本宏（`keyboardSetUnicodeString` 的能力保留但不暴露）。

## 5. 桌面切换

- "桌面左/右"即预设组合（⌃← / ⌃→），与快捷键共用注入通道，不引入私有 CGS API。
- 系统行为：位于最左/最右空间时无操作，不报错。
- 依赖系统快捷键保持默认（系统设置 → 键盘 → 键盘快捷键 → 调度中心）；被用户改键时可能无效，UI 与文档说明。

## 6. Mac 端 UI

- 「添加按钮」拆为菜单：**添加应用按钮…**（现有流程）/ **添加快捷操作…**。
- 添加快捷操作 Sheet：
  - 左列预设清单（图标 + 符号 + 名称），单选即创建；
  - 右列自定义编辑器：修饰键切换按钮（⌘⌃⌥⇧Fn）+ 主键下拉（字母/数字/方向/功能键），实时预览符号；
  - 「录制」模式：Sheet 内置 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 捕获组合；纯修饰键不结束录制；Esc 取消；与拼凑模式共享同一组合数据结构。
  - 校验：主键为空 → 禁止保存；与同类型按钮组合重复 → 提示并禁止保存。
- 按钮列表行：显示类型标签（应用/快捷操作）；快捷操作行支持「编辑组合…」「重命名…」「删除…」与分组内排序。
- 组合符号生成：`⌃⌥⇧⌘` 固定顺序 + keyLabel（方向键显示 ←↑↓→，回车 ↩，Esc ⎋）。

## 7. 手机面板

### 7.1 布局：上下双区，底部固定

```
┌─────────────────────────────┐
│ ● 已连接        状态条（固定）│
├─────────────────────────────┤
│ 应用（占剩余高度，可滚动）    │
│  2 列网格（竖屏）/ 3–4 列（横屏）
│  ↑↓ 内容超高时区内滑动        │
├─────────────────────────────┤
│ 快捷操作（固定底部 ~1/3 高）  │
│  3 列（竖屏）/ 4–6 列（横屏） │
│  ↑↓ 超出时区内滑动            │
└─────────────────────────────┘
```

- 结构：`header(状态)` + `main(应用区, flex:1, overflow-y:auto)` + `footer(快捷操作区, height: ~34vh + 安全区)`。
- 底部高度用 `min(34vh, 内容高度)`：快捷操作少时自然收缩，不强行留白；多时封顶 34vh，区内滚动。
- 各自独立滚动容器，互不联动；`-webkit-overflow-scrolling: touch` 保证惯性滑动。
- 安全区：`padding-bottom: env(safe-area-inset-bottom)`；底部区背景使用模糊/纯色遮挡下方内容，避免透字。
- 空分组：应用或快捷操作任一为空时，对应区域不渲染，另一区占满高度。
- 列数：CSS Grid `repeat(auto-fill, minmax(…)`，竖屏快捷操作 3 列、应用 2 列；横屏相应增加。

### 7.2 数据与渲染

- `GET /api/buttons` 返回 `kind`、`group`（app/shortcut）、`symbol`、`iconURL`、`sortOrder`。
- 应用区渲染图标+名称；快捷操作区以组合符号为大字（⌘C、⌃→、F5），名称在下。
- 状态行置于底部区顶部或按钮下方，触发期间仅禁用被点按钮并显示「正在发送…」；结果文案按类型区分（已发送快捷键 / 需要辅助功能权限 / 安全输入模式）。
## 8. API 契约

- `POST /api/activate`（路径不变，兼容现有面板）：
  ```json
  { "accepted": true, "kind": "shortcut", "status": "sent", "message": "已发送快捷键" }
  ```
  - 应用按钮：`status` 保持现有取值（`launched/activated/unconfirmed`）；
  - 快捷操作：`status = sent`；失败时 `status = shortcut-failed` + `error = accessibility-required | secure-input | injection-failed`，HTTP 仍为 200 或 4xx 按现有错误规范（配置不存在 404，权限问题 403 与文案）。
- `GET /api/buttons` 增字段（向后兼容）：`kind`、`symbol`、`group`。

## 9. 测试策略

单元测试：

- 键码/修饰键映射表（预设覆盖、符号生成）；
- 组合校验（无主键、重复、修饰键归一化）；
- 配置迁移（旧 JSON → app，新 JSON 往返）；
- 路由分派（app vs shortcut、未知按钮、请求体不含组合字段）。

集成/手动：

- TextEdit 中验证 ⌘A/⌘C/⌘V/⌘Z；
- 浏览器验证 ⌘T / ⌘W（可选）；
- 桌面左/右切换（截图确认空间变化与返回）；
- F1–F12（在支持的应用中验证，如 IDE 的快捷键面板）；
- 无辅助功能权限时的失败文案；密码框场景的安全输入文案。

## 10. 风险与取舍

- **安全输入**：注入被系统忽略时只能如实报错；
- **F1–F12**：受"将 F1、F2 等用作标准功能键"设置影响；Fn 组合作为修饰键注入，行为依键盘类型（内置/外接）可能不同；
- **桌面切换**：依赖系统默认快捷键；用户改键或关闭后失效；
- **不支持多键序列**（⌘K ⌘S）：留作后续能力，模型可扩展为 `sequence: [combo]`；
- **快速连点**：面板侧只做单按钮节流（请求期间禁用），不做全局队列；
- **输入法**：组合键注入对中文输入法通常无影响，但个别应用自绘输入处理可能忽略注入事件（如实反馈，不重试）。
