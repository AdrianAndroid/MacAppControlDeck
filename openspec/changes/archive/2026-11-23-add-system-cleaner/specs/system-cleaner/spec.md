# system-cleaner 变更（add-system-cleaner）

## ADDED Requirements

### Requirement: PureMac 作为单一功能模块

PureMac SHALL 作为本项目的一个 `FeatureModule`（id `systemTool`）存在，通过一个菜单分组、一个设置页 Tab 和一个原生 SwiftUI 窗口对外提供全部子功能。

#### Scenario: 模块启用与入口

- **WHEN** 用户在设置→模块中启用 PureMac
- **THEN** 菜单栏出现「PureMac」分组，且「快捷操作」子菜单出现「打开 PureMac」
- **AND** 手机面板「快捷操作」区出现同名按钮
- **AND** 设置→按钮管理→添加内置操作中可添加 `systemTool.open`

#### Scenario: 模块禁用

- **WHEN** 用户禁用 PureMac 模块
- **THEN** 菜单栏两个状态项、模块菜单与内置按钮入口全部消失
- **AND** 定时器停止、未完成的按需扫描取消、结果对象释放
- **AND** 状态栏展示信息的勾选状态保留；重新启用模块后按勾选恢复显示

### Requirement: 分类扫描与先看后删

清理功能 SHALL 在删除前展示每条的具体路径、大小和类别，且任何条目默认都不选中。

#### Scenario: 扫描结果默认不删

- **WHEN** 用户执行一次垃圾/缓存或大文件扫描
- **THEN** 结果列表展示每条的路径、大小、修改时间与分类
- **AND** 所有条目默认未选中，界面没有任何"选中即删"的隐式动作
- **AND** 显示可清理总大小，该数值按当前选中项实时更新

#### Scenario: 用户确认后清理

- **WHEN** 用户勾选条目并点击清理
- **THEN** 弹出确认，列出选中条目数量、总大小和"移入废纸篓"字样
- **AND** 确认后执行；若勾选了永久删除，则再次单独确认
- **AND** 结果显示成功数、跳过数与失败数
- **AND** 凡由扫描产生并展示给用户的条目（含大文件、开发缓存、Xcode 缓存、沙盒容器缓存）均须真正移入废纸篓，不得被安全校验静默跳过

#### Scenario: 扫描范围与清理范围一致

- **WHEN** 系统校验一条待清理路径是否允许删除
- **THEN** 允许范围 SHALL 与 `ScanEngine` 实际会产出条目的扫描根共享同一份定义（`SystemToolScanRoots`），两处不得各自维护清单
- **AND** 大文件扫描根（默认下载/文稿/桌面，或用户在设置页自定义的绝对目录）纳入允许范围
- **AND** 原始路径与符号链接解析后的路径都必须落在允许范围内，防止 TOCTOU 逃逸
- **AND** 系统关键路径与家目录敏感点目录（`/System`、`/etc`、`~/.ssh`、`~/Library/Keychains` 等）由 denylist 优先拒绝，不因允许范围放宽而失效
- **AND** 符号链接、SIP/immutable 保护路径、排除路径与云同步 File Provider 状态仍按既有规则跳过

#### Scenario: 扫描可取消

- **WHEN** 用户在扫描进行中点击取消或关闭窗口
- **THEN** 扫描在当前检查点停止，不产生任何删除
- **AND** 已扫描到的部分结果被丢弃或明确标注为"未完成"

### Requirement: 应用卸载与残留分级

应用卸载 SHALL 按 bundle ID 与应用容器路径发现关联文件，并对删除风险分级展示。

#### Scenario: 卸载应用

- **WHEN** 用户选择一个已安装应用并确认卸载
- **THEN** 应用包先移入废纸篓
- **AND** 列出发现的关联文件，分为"高置信残留"与"需人工核对"两组
- **AND** 只有高置信残留可批量勾选；需人工核对的项必须逐项勾选

#### Scenario: 安全策略拦截

- **WHEN** 关联文件路径命中系统路径或符号链接保护规则
- **THEN** 该路径被跳过、不可勾选
- **AND** 结果中计入跳过数并说明原因

### Requirement: 重复文件清理

重复文件功能 SHALL 以内容哈希分组，每组保留一份，其余只有经用户确认才移入废纸篓。

#### Scenario: 扫描重复文件

- **WHEN** 用户指定扫描根目录并启动
- **THEN** 按 SHA-256 内容哈希分组，忽略符号链接、包、云占位文件与 dataless 文件
- **AND** 每组显示文件大小、文件数与可释放空间
- **AND** 每组的 `keeper` 默认不选，其余默认不选

#### Scenario: 移入废纸篓

- **WHEN** 用户勾选组内文件并确认
- **THEN** 勾选文件移入废纸篓
- **AND** 该组的 keeper 与未勾选文件不受影响

#### Scenario: 扫描上限

- **WHEN** 扫描达到上游设定的文件数或目录项上限
- **THEN** 扫描停止并显示"已达到扫描上限，结果可能不完整"
- **AND** 已找到的分组仍然可查看和操作

### Requirement: 菜单栏 CPU/MEM 与进程退出

菜单栏 SHALL 常驻显示 CPU 与内存占用；应用列表 SHALL 支持退出与强制退出，并对不可退出进程明确置灰。

#### Scenario: 菜单栏采样

- **WHEN** PureMac 模块启用
- **THEN** 菜单栏新增两个独立的状态项（仿柠檬截图分栏形态）：CPU 项上下两行显示数值与标签 `CPU`，MEM 项上下两行显示占用百分比与标签 `MEM`（与现有的聚合菜单状态项并存、互不改动），按固定间隔刷新
- **AND** 点击任一状态项直接打开 PureMac 窗口，不挂下拉菜单
- **AND** 设置→PureMac 的状态栏展示信息设置里，CPU、MEM 可分别勾选，勾掉即不创建对应状态项，改动即时生效；不另设菜单栏总开关，模块启用开关即总闸
- **AND** 不显示温度、网速上下行、音频设备图标
- **AND** 采样只读系统 API，不申请 TCC 权限
- **AND** 模块禁用或 App 退出时两个状态项移除、定时器停止

#### Scenario: 优雅退出

- **WHEN** 用户在进程列表对普通应用点击"退出"
- **THEN** 调用 `NSRunningApplication.terminate()`
- **AND** 应用按自身流程退出（可提示保存），不被强杀

#### Scenario: 强制退出

- **WHEN** 用户对进程点击"强制退出"
- **THEN** 先弹出确认，写明未保存内容会丢失
- **AND** 确认后调用 `forceTerminate()`

#### Scenario: 不可退出进程

- **WHEN** 进程是系统进程、root 进程或受 SIP 保护
- **THEN** 退出与强制退出按钮不可用
- **AND** 该行显示"系统进程不可退出"，点击不产生任何动作

### Requirement: 完全磁盘访问按需申请

PureMac SHALL 在未获得完全磁盘访问时可扫描，但必须明确标注结果不完整。

#### Scenario: 未授权扫描

- **WHEN** 用户未授予完全磁盘访问并启动扫描
- **THEN** 扫描可访问范围内的路径
- **AND** 结果页顶部显示"部分目录未授权，结果不完整"并给出打开系统设置的按钮
- **AND** 不阻塞扫描、不强制跳转授权、不记录扫描路径到日志

#### Scenario: 授权后重扫

- **WHEN** 用户授予完全磁盘访问后重新扫描
- **THEN** 不完整提示消失
- **AND** 原先因权限跳过的目录被纳入扫描

### Requirement: 签名与授权稳定

PureMac SHALL 不改变本项目的签名身份、Bundle ID、runtime 标志与既有 TCC 授权。

#### Scenario: 构建与覆盖安装

- **WHEN** 按构建流程打包并覆盖 `/Applications/MacAppControlDeck.app`
- **THEN** 使用固定身份签名，designated requirement 仍为 certificate root 形式
- **AND** `verify-signing.sh` 校验通过
- **AND** 辅助功能、输入监控、屏幕录制、自动化授权不需重新授予

#### Scenario: 无特权 helper

- **WHEN** 用户使用 PureMac 的任何功能
- **THEN** 不出现管理员密码弹窗、不安装 privileged helper
- **AND** 不请求与内存释放相关的系统级权限
