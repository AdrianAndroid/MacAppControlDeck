# Change: 菜单栏实时网速监测（对齐腾讯柠檬）

## Why

PureMac 菜单栏已有 CPU / MEM 状态项，但缺少实时网速。腾讯柠檬把网速作为状态栏核心信息（官网主打「状态栏实时显示网速」），用户实测确认后要求实现同样的能力，单位写 `K/s` / `M/s`。

调研证据与技术方案见 `Docs/research/2026-11-24-lemon-netspeed-research.md`：柠檬的「网速监测」其实是三件事（实时网速状态项、主动网络测速、按进程流量/端口），本次只做第一件——菜单栏实时上下行速率，改动最小、零 TCC 权限。

## What Changes

1. `SystemSampler.swift` 新增网速采样：用公开 API `getifaddrs()` 读取所有活动网络接口（en*/utun*，跳过 lo0）的累计收发字节，每 2 秒与上次差分得上行/下行速率（B/s）；累计值回绕（接口重置）时当次记 0，不产生负数。复用现有 2 秒定时器，不新增常驻线程。
2. `SystemToolModule.swift` 把 CPU / MEM / 网速拆成**三个独立 NSStatusItem**，各自可单独点击与开关（用户 2026-11-24 选定「分开点击」，因此不采用柠檬的紧凑合栏形态）。按 macOS 状态栏从右往左的排列规则反序创建，使从左到右呈现 CPU → MEM → 网速。
3. 单位格式化：B/s 起按量级自动切 `K/s` → `M/s`，保留 1 位小数；无数据帧显示 `0 K/s`。
4. **定宽与统一样式**（对齐柠檬的关键细节）：菜单栏网速用 `formatSpeedFixed(_:)` 以 figure space (U+2007) 把数值右对齐填到 5 字符，单位固定 3 字符，配 9pt 等宽数字字体 + 固定列宽，数值位数变化（`17.0`→`336.0`）时该项宽度恒定、小数点对齐；↑上行 / ↓下行两行同为 9pt、同为 `.labelColor`，只靠箭头区分方向，不再用 ↑绿 / ↓蓝双字号。
5. `SystemToolSettingsView.swift` 在 CPU / MEM 之外新增「实时网速」勾选开关（设置写 `systemTool.menubar.showNetSpeed`），与状态项显示同源；三者全关时对应状态项全部消失。
6. `system-cleaner` 能力增加「菜单栏实时网速」要求与对应场景。
7. 新增单元测试覆盖单位格式化、定宽格式与差分/回绕逻辑。

## Capabilities

### Modified Capabilities

- `system-cleaner`：新增三个独立状态项与菜单栏实时网速显示要求。

## Impact

- 代码：`SystemSampler.swift`、`SystemToolModule.swift`、`SystemToolSettingsView.swift` + 测试文件；`StatusMetricView` 保留多列/竖线绘制能力但每项当前只放一列。
- 权限：`getifaddrs()` 是公开 API，**不申请任何 TCC 权限**，与现有 CPU/MEM 采样一致。
- 依赖：无新增 SPM 依赖；不引入 nettop / 私有 NetworkStatistics.framework。
- 安全边界：不触碰清理路径白名单、默认零选中、废纸篓优先等既有契约。
- 用户可见：菜单栏新增第三个独立网速状态项（两行同色同字号、定宽不抖）；设置页多一个开关。
- 已知限制：`getifaddrs` 的 if_data 为 32 位字段，长时间累计会回绕（差分时归零处理）；对第三方签名有 1KiB 批量化取整，仅影响速率精度、不影响量级判断。
