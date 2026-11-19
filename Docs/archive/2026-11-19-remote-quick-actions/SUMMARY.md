# 总结：远程快捷操作（add-remote-quick-actions 实现与验证）

- 日期：2026-11-19
- 对应变更：`openspec/changes/archive/2026-11-19-add-remote-quick-actions`（先设计后实现）
- 状态：已实现并真机验证（应用激活部分沿用 `add-core-control-loop` 的既有能力）

## 一、交付内容

| 能力 | 实现 |
| --- | --- |
| 快捷操作按钮 | `ButtonKind.shortcut` + `ShortcutCombo`（修饰键 + virtual keycode + 展示标签），预设 20 项（桌面左/右、⌘C/⌘V/⌘A/⌘Z、回车、Esc、F1–F12） |
| 自定义组合 | Mac 端 Sheet：修饰键拼凑 + 实际按键录制（`NSEvent` 本地监听，Esc 取消、纯修饰键不结束）；查重与空主键校验 |
| 命令按钮 | `ButtonKind.command`：执行应用内置 CLI（如 Snipaste `snip`），参数仅存在 Mac 端；手机仍只发送按钮 ID |
| 注入执行 | `KeyInjector`：CGEvent（辅助功能/安全输入检查）→ 随包 CLI 助手 `KeySender` → System Events（仅桌面切换） |
| 桌面切换 | 通过 System Events 发送 ⌃←/⌃→（WindowServer 系统快捷键忽略直接注入） |
| 手机面板 | 上下双区、整页翻页：应用区 8/12 个每页，快捷操作 12 宫格（竖屏 4×3 / 横屏 6×2），手势翻页 + 页点 |
| 权限引导 | 顶部四行状态与一键跳转：服务 / 辅助功能 / 输入监控 / 调度中心开关；快捷操作失败按类型给明确原因 |

## 二、成功经验（按"踩坑 → 结论"记录）

### 1. 全局热键类应用忽略合成事件（Snipaste / F1）
- 现象：Deck 注入 F1 → 普通应用能收到（KeyProbe 验证 keyCode=122），但 Snipaste 无反应；同一段代码从普通脚本进程注入却能触发。
- 排查：换 HID 事件源、伪造 sourcePID、主线程投递、独立 CLI 子进程、System Events 均无效；授权「输入监控」也无效。
- 结论：注册系统级热键的应用对"由本 GUI 进程投递"的合成事件有过滤，公开 API 无法绕过。
- 解法：新增**命令按钮**，调用应用自身 CLI（`Snipaste snip`），实测截图界面正常弹出。

### 2. WindowServer 系统快捷键忽略合成按键（桌面左/右）
- 现象：`⌃←/⌃→` 注入后空间不变（脚本与 Deck 均无效；早期一次"成功"是截图误判）。
- 结论：系统级空间切换不消费合成事件。
- 解法：改走 **System Events**（`osascript ... key code 123 using control down`），实测左右切换与边界行为正常；需要一次性「自动化」授权。

### 3. 系统界面型"应用"（Launchpad）
- 现象：点击启动台后长时间"正在打开"，最终"未确认"。
- 原因：启动台不常驻常规进程，代码等满 15 秒并跑完整降级链。
- 解法：等待缩短为 4 秒 + 识别启动台给出专用文案（实测 4.5 秒返回「已打开启动台…」）。

### 4. 权限与签名（反复失效的根因）
- TCC 授权（辅助功能/输入监控/自动化）按**签名**绑定；ad-hoc 每次重建都会让旧授权"看起来开着、实际无效"。
- 解法：稳定自签名证书（`Build/setup-signing.sh`），重建不丢授权；授权异常时删除条目重新添加并重启程序。
- 权限矩阵：
  - 辅助功能：跨桌面激活（Dock AXPress）、普通应用按键注入
  - 输入监控：部分第三方应用全局热键（对 Snipaste 实测无效，保留状态展示）
  - 自动化：桌面左/右（System Events）
  - 调度中心开关：跨桌面跟随（读取实际值并在 UI 展示）

### 5. 判定依据要选可信信号
- 进程内 `CGWindowList` 与其他进程数据不一致（已在上个变更证实），本次沿用"目标应用成为前台"作为激活成功判定；窗口可见性只记日志。
- 快捷键注入"成功"只能表示事件已发出，面板文案用"已发送快捷键 / 已执行命令"，不承诺应用响应。

### 6. 真机验证方法沉淀
| 目标 | 方法 |
| --- | --- |
| 复制 | 全选后触发 ⌘C，读 `NSPasteboard` |
| 粘贴 | 剪贴板写入标记文本，触发 ⌘V 后用 AX 读文本框内容 |
| F1 / Esc | 前台按键探针 App 记录 `keyCode`（122 / 53） |
| 桌面切换 | 采样屏上应用集合作为"空间签名"，连续左右验证循环与边界 |
| Snipaste | 读取 `~/.snipaste/splog.txt` 增量判断是否触发 |
| Launchpad | API 返回耗时与文案 |

## 三、验证结论

| 场景 | 结果 |
| --- | --- |
| 复制 ⌘C / 粘贴 ⌘V（TextEdit） | 通过 |
| F1 / Esc 注入（普通应用） | 通过（keyCode 122 / 53） |
| F1 → Snipaste | 不支持（改命令按钮，通过） |
| 桌面左 / 右 | 通过（System Events） |
| Launchpad | 4.5 秒返回明确文案 |
| 单元测试 | 26 项全部通过（含命令路由、组合校验、迁移、空间切换分类） |

## 四、已知限制

- Snipaste 等全局热键应用需用命令按钮触发（见 README「已知限制」）。
- 命令按钮执行应用 CLI：参数由 Mac 端配置，手机端无法注入任意参数；仍建议只绑定可信应用。
- 桌面切换依赖系统默认快捷键（⌃←/⌃→）与「自动化」授权；用户改键后可能失效。
- F1–F12 的效果受「将 F1、F2 用作标准功能键」设置影响。
- 安全输入（密码框）期间注入会被系统忽略，已如实提示。

## 五、代码索引

- 模型：`Sources/MacAppControlDeck/Model/Models.swift`（kind/shortcut/command）
- 注入：`Sources/MacAppControlDeck/Control/KeyInjector.swift`
- 助手：`Sources/KeySender/main.swift`（随包 `<App>/Contents/MacOS/KeySender`）
- 命令：`Sources/MacAppControlDeck/Control/CommandRunner.swift`
- 路由：`Sources/MacAppControlDeck/Server/APIRouter.swift`
- UI：`Sources/MacAppControlDeck/UI/{MainWindowView,ShortcutSheet,CommandSheet}.swift`
- 面板：`Sources/MacAppControlDeck/Panel/PanelHTML.swift`
- 测试：`Tests/MacAppControlDeckTests/ShortcutActionsTests.swift`
