# 设计：菜单栏实时网速监测

## 1. 参考与实测

柠檬 5.3.7 菜单栏实测（放大截图证据见调研文档）：

```
30%  |  58%  |  52°C  | ↑34.8 K/s
CPU     MEM     SEN    ↓10.8 K/s
```

- 四项同处一个状态项组，竖线分隔；网速占最后一列，两行分别是上传（↑）与下载（↓）。
- 单位 K/s，1 位小数；二进制含 `%ld KB/s` / `%.2f MB/s` / `Kbps` / `Mbps`，说明按量级切档。
- 常驻进程 LemonMonitor 承载，主 App 不启动也显示——与 PureMac 常驻状态项架构一致。

PureMac 无温度项（不引入 SMC/私有 API）。最初规划合并为一条竖线分栏项，但用户验收时选了「三个独立状态项、可分别点击」，最终形态为三个独立图标（从左到右）：

```
23% CPU    57% MEM    ↑ 336.0 K/s
  CPU        MEM      ↓ 9.0 K/s
```

网速项两行同字号同色（仅靠箭头区分方向），数值定宽右对齐、小数点对齐，宽度不随速率变化。

## 2. 数据流

```
getifaddrs()  ──读 if_data.ifi_ibytes / obytes（所有 en*/utun*，跳 lo0）
     │  2 秒一次（复用 SystemSampler 定时器）
     ▼
累计字节差分：Δrx / Δt = 下行 B/s，Δtx / Δt = 上行 B/s
     │  回绕保护：本次 < 上次 → 记 0
     ▼
格式化：B/s → K/s → M/s（1 位小数，无数据 0 K/s）
     │  @Published 推送
     ▼
StatusMetricView 多列自绘：CPU% | MEM% | ↑x K/s / ↓y K/s
```

## 3. 关键决策

1. **用 getifaddrs，不用私有 API**：公开、零 TCC、实测可用；if_data 32 位回绕用差分归零兜底。不做 NET_RT_IFLIST2（64 位但第三方签名有 1KiB 批量化与 4GiB 截断 bug），本项目只需"看个大概速率"。
2. **接口聚合**：遍历所有活动接口，累加 `ifi_ibytes`/`ifi_obytes`；跳过 loopback（lo0）与全零空闲接口；utun* 计入以覆盖 VPN 流量。
3. **三个独立状态项**（用户 2026-11-24 选定：拆成三个独立图标，可分别点击、单独开关；改变柠檬紧凑合栏外观）：CPU / MEM / 网速各建一个 NSStatusItem，各自 `variableLength`、各自 target/action（点击均打开 PureMac），由 `showCPU/showMEM/showNetSpeed` 独立控制存在与否；采样变化只刷新对应项。`StatusMetricView` 保留多列/竖线绘制能力，但每项当前只放一列。
   - CPU/MEM 列宽度自适应内容（`NN%` 位数稳定，可接受）。
   - **网速列固定宽度**：对齐柠檬——`formatSpeedFixed(_:)` 用 figure space (U+2007) 把数值右对齐填充到 5 字符（"   0.0"~"999.9"，U+2007 与数字等宽），单位固定 3 字符（B/s·K/s·M/s·G/s）；配 `monospacedDigitSystemFont(ofSize:9)` 使整串宽度恒定。网速列不随数值位数变化而抖动；`StatusMetricColumn` 增加 `font` / `fixedWidth` 覆盖字段承载。
   - **网速上下两行统一**：↑上传 / ↓下载同为 9pt、同为 `.labelColor`（跟随深浅色），只靠箭头区分方向；不再用 ↑绿 / ↓蓝 + 11pt/8pt 双字号。CPU/MEM 仍保持"上数值 11pt / 下标签 8pt"。
4. **自绘而非 attributedTitle**：延续上次修复——多行富文本在 NSStatusItem 顶部被裁，继续用 NSView `draw(at:)`（左下角坐标）精确布局，确保数值完整居中。
5. **权限与安全**：零 TCC 权限；不改清理引擎、签名、Bundle ID；与 CPU/MEM 共用同一采样定时器与生命周期（模块启用启动、禁用停止）。

## 4. 落地映射

| 文件 | 改动 |
| --- | --- |
| `Modules/SystemTool/SystemSampler.swift` | 新增 `@Published uploadBytesPerSec` / `downloadBytesPerSec`；`sample()` 调 `sampleNetwork()`；`getifaddrs` 读累计字节并差分、回绕归零；提供纯函数 `formatSpeed(_:)`（通用）与 `formatSpeedFixed(_:)`（菜单栏定宽，figure space 填充）|
| `Modules/SystemTool/SystemToolModule.swift` | 从单一合并状态项改为创建**三个独立** `NSStatusItem`（反序创建保证 CPU→MEM→网速 顺序），各自 target/action 可点击、各自开关控制；`StatusMetricView` 支持每列自定义字体与固定列宽承载网速定宽；订阅三路采样值分别刷新对应项；`showNetSpeed` 偏好键 |
| `Modules/SystemTool/SystemToolSettingsView.swift` | 加 `showNetSpeed` 开关与示例卡片，三开关变更统一通知重建状态项 |
| `Tests/MacAppControlDeckTests/SystemToolTests.swift` | 测单位格式化（B/K/M 切档、1 位小数、0 值）与差分回绕归零 |

## 5. 验收

- 菜单栏出现**三个独立状态项**：CPU%、MEM%、↑x/↓y 网速，各自可单独点击（均打开 PureMac），数字完整不被裁。
- 网速项**宽度恒定**：速率数值位数变化（如 `17.0`→`336.0`）时该项左右边界不移动；上下两行同字号同色、小数点对齐（定宽右对齐）。
- 开关任一指标后对应状态项增/删（互不影响）；三者全关后状态项全部消失；设置页开关与显示一致。
- 速率量级与活动监视器/柠檬一致；断开网络或回绕时归零、无负数。
- `swift build` 通过、`SystemToolTests` 全绿；release 构建 + 固定签名 + 覆盖安装截图验收。

## 6. 已知限制

- getifaddrs 32 位字段长时间累计回绕——差分归零处理，最坏情况某次速率显示为 0，下一采样恢复。
- 第三方签名的 1KiB 批量化取整会让低速时显示略粗，但量级正确。
- 不做按进程流量拆分（C）与主动测速（B），见调研文档。
