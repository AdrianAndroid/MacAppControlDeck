# app-control Specification

## Purpose
TBD - created by archiving change add-core-control-loop. Update Purpose after archive.

## Requirements

### Requirement: 按 Bundle ID 定位目标应用

系统 SHALL 以应用的 Bundle Identifier 为唯一主键定位目标应用，并在按钮配置中同时保存显示名与可执行路径作为辅助信息。

#### Scenario: Bundle ID 正常定位

- **WHEN** 收到激活请求且该 Bundle ID 对应的应用已安装
- **THEN** 系统用 `NSWorkspace` 按 Bundle ID 找到应用与路径，并继续执行启动或激活
- **AND** 找到多个同名应用时选择优先级最高的安装位置（如 `/Applications`）

#### Scenario: 应用已卸载或路径失效

- **WHEN** 按钮绑定的 Bundle ID 在本机找不到任何已安装应用
- **THEN** 不执行任何动作，向前端返回明确的"应用未找到（可能已卸载）"错误
- **AND** Mac 端 UI 中的该按钮显示"应用缺失"标记，提示用户重新绑定

### Requirement: 启动未运行的应用

系统 SHALL 在目标应用未运行时通过 `NSWorkspace.openApplication` 启动它，并以系统回调结果确认是否成功。

#### Scenario: 应用未运行

- **WHEN** 目标应用不在 `NSWorkspace.runningApplications` 列表中
- **THEN** 调用 `NSWorkspace.shared.openApplication(at:configuration:)` 启动应用
- **AND** 启动成功返回"已启动"，启动失败（如应用损坏）返回真实错误信息

#### Scenario: 应用路径存在但启动被系统拒绝

- **WHEN** 启动回调返回错误（如 Gatekeeper 阻止、应用损坏）
- **THEN** 不报告"已启动"，向前端返回包含系统错误描述的失败信息

### Requirement: 激活已运行的应用并切到前台（含跨桌面空间）

系统 SHALL 采用"等价真人点击 Dock"的激活路径，在具备辅助功能权限时优先通过 Dock 图标 AXPress 完成激活，从而复用系统调度中心的跨空间规则；成功与否以"目标应用是否成为前台应用"为准。

#### Scenario: 已运行未隐藏的应用（辅助功能已授权）

- **WHEN** 目标应用正在运行、未被隐藏，且本程序已获得辅助功能权限
- **THEN** 在 Dock 中定位该应用的图标项并执行 `AXPress`，由 Dock 进程完成激活
- **AND** 若系统开关「切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间」开启，系统自行切到窗口所在空间
- **AND** 目标应用成为前台后返回"已切换到前台"

#### Scenario: 已运行但窗口在其他桌面空间（含 JetBrains 类应用的卡死态）

- **WHEN** 目标应用被系统标记为前台但窗口位于其他桌面空间，常规激活 API 已失效
- **THEN** Dock 图标 AXPress 仍 SHALL 生效并完成空间切换（实测可恢复）
- **AND** 不因"进程内窗口可见性为 0"而判定失败或提示重启应用

#### Scenario: 目标应用不在 Dock 中

- **WHEN** Dock 中不存在该应用的图标项
- **THEN** 依次尝试 AXRaise 目标窗口（取消最小化后 `kAXRaiseAction`）、`activate(from:)`、LSOpen
- **AND** 全部未达成前台时，如实返回失败原因与当前前台应用

#### Scenario: 已被隐藏的应用

- **WHEN** 目标应用处于隐藏（hidden）状态
- **THEN** 激活后由系统取消隐藏并切到前台，返回结果中说明"已取消隐藏"

#### Scenario: 成功判定不依赖窗口列表

- **WHEN** 判定激活是否成功
- **THEN** 仅以 `NSWorkspace.frontmostApplication` 是否为目标应用作为成功条件
- **AND** `CGWindowListCopyWindowInfo` 的可见性结果只写入诊断日志，不作为成功或失败依据

#### Scenario: 已运行但无可见窗口

- **WHEN** 目标应用正在运行但没有任何可见窗口（如菜单栏应用）
- **THEN** 激活照常执行，并按 `activationPolicy` 如实反馈"无可见窗口"
- **AND** 系统不模拟键盘快捷键或菜单命令去强制新建窗口

### Requirement: 最小化窗口的恢复与如实反馈

系统 SHALL 在目标应用窗口最小化时执行常规激活，并且只在系统行为可确认时报告窗口恢复成功。

#### Scenario: 窗口最小化的应用被激活

- **WHEN** 目标应用的所有窗口都被最小化，用户请求激活
- **THEN** 执行 `activate`，由系统恢复最小化窗口（多数应用下有效）
- **AND** 若激活回调后无法确认窗口已重新可见，反馈"已激活，但未能确认最小化窗口已恢复"，不谎报成功

### Requirement: 多窗口应用的行为边界

系统 SHALL 对同一应用多窗口的情形采用系统默认选择（激活的前台窗口），并在文档中说明该限制。

#### Scenario: 同一应用多个窗口

- **WHEN** 目标应用打开了多个窗口
- **THEN** 激活应用由系统选择其当前主窗口（通常为最近使用的窗口）
- **AND** 第一版不提供按具体窗口选择的能力

### Requirement: 不干扰其他应用

系统 SHALL 只对请求的目标应用执行启动与激活，绝不关闭、移动、修改其他应用或系统状态。

#### Scenario: 只影响目标应用

- **WHEN** 执行任意一次启动或激活
- **THEN** 其他运行中的应用不被退出、隐藏、移动窗口或修改
- **AND** 不执行任何 shell 命令、不做系统配置变更

### Requirement: 空间切换的系统能力与前置设置

系统 SHALL 把跨桌面空间的切换交给 macOS 官方行为完成，并在 UI 与文档中显式告知关键系统开关，不承诺无条件切换。

#### Scenario: 用户打开设置说明

- **WHEN** 用户查看 Mac 端说明或使用文档
- **THEN** 能看到开关键名、完整路径（桌面与程序坞 → 调度中心 →「切换到某个应用程序时，会切换到包含该应用程序的打开窗口的空间」）以及"未开启时表现为只切菜单栏、不跳桌面"的说明
- **AND** 文档给出判断方法：手动点 Dock 图标也不跳桌面即为此开关问题

#### Scenario: 空间切换未达到预期时不伪造成功

- **WHEN** 激活动作已成功但用户仍停留在原空间（窗口在其他空间的切换由系统决定）
- **THEN** 界面反馈为"已激活"，并附带"若未切换空间，请检查上述系统设置"的指引
- **AND** 不出现"已切换空间"这类未经确认的措辞
