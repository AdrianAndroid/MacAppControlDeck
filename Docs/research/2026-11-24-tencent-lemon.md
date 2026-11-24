# 腾讯柠檬清理（Tencent Lemon）功能调研方案

- 日期：2026-11-24
- 状态：进行中（已采集 6 张，剩余 6 个功能页待补）
- 关联变更：`openspec/changes/add-puremac-ui-redesign-and-lemon-research/`
- 用途：作为 PureMac 模块的功能与交互对照，不作为源码参考

## 1. 被测对象与环境

| 项 | 值 |
| --- | --- |
| App | Tencent Lemon（腾讯柠檬清理） |
| 版本 | 5.3.9 |
| Bundle ID | `com.tencent.Lemon` |
| 路径 | `/Applications/Tencent Lemon.app` |
| 系统 | macOS 14+（本机 3456×2234 Retina，逻辑 1728×1117） |
| 调研宿主 | Orca 1.4.272（`orca computer` 后台驱动） |
| 固定签名 | 本机 `MacAppControlDeck Self-Signed`（与被测 App 无关） |

主窗口 1000×618，功能子窗口 780×482。

## 2. 目标

1. 记录柠檬全部功能入口、页面结构、操作流程与关键文案。
2. 为 PureMac 的 UI 重做提供对照：哪些交互值得借鉴、哪些刻意不采用。
3. 全程尽量不打断用户当前工作；必要时经用户授权短暂前台操作。

## 3. 功能地图

首页右侧 8 个入口，左侧为智能扫描主操作：

```
┌ 首页（1000×618）──────────────────────────────────────────────────────┐
│  ┌ 引导区 ──────────────┐   ┌ 工具网格 ────────────────────────────┐ │
│  │  畅快清理，清爽一下   │   │ 大文件清理      重复文件清理          │ │
│  │  欢迎使用 Lemon      │   │ 相似照片清理    应用卸载              │ │
│  │  [ 开始扫描 ]        │   │ 隐私清理        开机启动项管理        │ │
│  └──────────────────────┘   │ 磁盘空间分析    柠檬精选              │ │
│  ┌ 广告条：柠檬 × WorkBuddy 一键安装 ──────────────────────────────┐ │
└──────────────────────────────────────────────────────────────────────┘
```

| # | 入口 | 副标题（实测文案） | 已采集 |
| --- | --- | --- | --- |
| 0 | 开始扫描 | 畅快清理，清爽一下 | 否 |
| 1 | 大文件清理 | 查找 50MB 以上的文件 | 是（入口 + 结果） |
| 2 | 重复文件清理 | 查找内容一样的文件 | 是（入口） |
| 3 | 相似照片清理 | 快速查找，准确筛选 | 是（入口） |
| 4 | 应用卸载 | 强力卸载已安装应用 | 是（列表） |
| 5 | 隐私清理 | 清理浏览器内敏感信息 | 否 |
| 6 | 开机启动项管理 | 快速禁用开机自启应用 | 否 |
| 7 | 磁盘空间分析 | 深度分析存储情况 | 否 |
| 8 | 柠檬精选 | 发现更多优质 Mac 应用 | 否 |

补充依据：App 内功能 framework 与入口一一对应，可作为"功能全集"的旁证：

```
LemonClener          LemonBigOldFile      LemonDuplicateFile
LemonPhotoClean      LemonUninstaller     LemonPrivacyClean
LemonLoginItemManager LemonSpaceAnalyse   LemonFileMove
LemonFileManager     LemonUpdate          LemonDaemon
```

## 4. 已采集证据

全部位于 `Docs/research/tencent-lemon/screenshots/`。

| 文件 | 界面 | 可确认的信息 |
| --- | --- | --- |
| `01-home.png` | 首页 | 8 个工具入口、智能扫描主按钮、底部广告条 |
| `02-bigfile-landing.png` | 大文件清理入口 | 标题、副标题、开始扫描按钮 |
| `03-bigfile-result.png` | 大文件扫描结果 | 总量、分类 tab、预览模式、按大小分组、逐项勾选 |
| `04-duplicate-landing.png` | 重复文件入口 | 拖拽/点击添加文件夹，未添加前开始扫描禁用 |
| `05-similar-photos-landing.png` | 相似照片入口 | 同上，文案强调"支持查找系统照片" |
| `06-uninstall-list.png` | 应用卸载列表 | 名称/大小/上次打开时间三列可排序、每行「卸载详情」、右上搜索与刷新 |

### 4.1 大文件清理（已观察）

- 入口：`开始扫描`，扫描前无参数可调。
- 结果页顶部：`发现 38.2 GB 大文件`、`请选择需要清理的文件`、`返回`、`立即清理`（未勾选时禁用）。
- 分类：`全部 / 音频 / 视频 / 文档 / 安装包 / 其他`。
- 右侧：`预览模式` 开关。
- 分组头：`1 GB 以上文件: 共 13 项，21.5 GB`，可折叠。
- 行：复选框、文件类型图标、文件名、大小；勾选后才启用清理。
- 未观察到：删除确认弹窗、删除后结果页、「其他大小区间」分组的完整形态。

### 4.2 重复文件清理（已观察）

- 入口：圆形 `+` 与文案 `点击或拖拽添加文件夹`。
- 未添加文件夹时 `开始扫描` 禁用。
- 未观察到：添加文件夹后的扫描中、分组结果、keeper 选择、删除确认。

### 4.3 相似照片清理（已观察）

- 入口与重复文件一致：拖拽/点击添加文件夹，扫描按钮禁用。
- 文案：`快速准确地查找相似或重复的照片，支持查找系统照片`。
- 未观察到：系统照片库授权、扫描结果、相似度阈值、分组。

### 4.4 应用卸载（已观察）

- 表头可排序：名称、大小、上次打开时间。
- 时间列文案包含 `安装后从未打开` 与具体日期（如 `2026年11月24日`）。
- 每行右侧：`卸载详情`。
- 右上：搜索框、刷新按钮。
- 未观察到：卸载详情/关联文件/残留列表（点击未成功，见 6.3）。

## 5. 调研方法 A：全后台（优先）

### 5.1 前置

```zsh
# /usr/local/bin/orca 是损坏的符号链接，必须用 App 内二进制
ORCA=/Applications/Orca.app/Contents/Resources/bin/orca
$ORCA computer capabilities --json
$ORCA computer launch-app com.tencent.Lemon --json
```

`launch-app` 不会把 App 带到前台（返回 `delivery: background`）。

### 5.2 读取窗口与截图

```zsh
$ORCA computer list-windows --app com.tencent.Lemon --json
$ORCA computer get-app-state --app com.tencent.Lemon --window-id <id> --screenshot-scale 1 --json
```

`result.screenshot.path` 在 `/var/folders/...`，直接 `cp` 会被本机路径策略拦截，需用 Python：

```python
import json, shutil
d = json.load(open('state.json'))
p = d['result']['screenshot']['path']
shutil.copy2(p, 'screenshots/xx.png')
```

仓库内已放 `tools/shot.sh` 做同样的事。

### 5.3 后台限制（实测）

| 操作 | 结果 |
| --- | --- |
| `click --element-index` 卡片 | 只把卡片置为 selected，不进入功能页 |
| `click --element-index` 卡片内空 button | `No change in the accessibility tree` |
| `click --x --y`（后台） | `background_unavailable`，未发送 |
| `press-key Return / Space / Tab` | 无变化，窗口无 AX 焦点 |
| `launch-app` | 可后台启动，`delivery: background` |

结论：柠檬的卡片是自绘控件，AX 只暴露"选中"，真正的进入动作依赖鼠标坐标；后台坐标点击被平台策略拒绝。

### 5.4 备选：CGEventPostToPid

仓库内 `tools/clickto.swift` 尝试用 `CGEvent.postToPid` 后台发送点击。本机实测未生效（多数情况下 TCC 不允许或 App 只处理 active 窗口的鼠标事件）。保留作为后续尝试，不作为可靠路径。

## 6. 调研方法 B：短暂前台（已获用户授权）

### 6.1 原则

- 只在需要进入下一层页面时使用，不在前台做浏览、搜索、删除。
- 每次操作后立刻 `list-windows` 重新取窗口 id；窗口会新建，旧 id 失效。
- 不点击任何"立即清理 / 卸载 / 删除"确认按钮。
- 结束后把前台切回 Orca。

### 6.2 主界面卡片坐标（window-local，1000×618）

```
┌──────────────────────────────────────────────────────────┐
│  (左区引导)          大文件(560,110)    重复文件(850,110) │
│                      相似照片(560,238)  应用卸载(850,238) │
│                      隐私清理(560,367)  启动项(850,367)   │
│                      磁盘分析(560,495)  柠檬精选(850,495) │
└──────────────────────────────────────────────────────────┘
```

打开一个功能：

```zsh
$ORCA computer click --app com.tencent.Lemon --window-id <主窗口id> \
  --x 560 --y 110 --restore-window --json
$ORCA computer list-windows --app com.tencent.Lemon --json   # 取新的 780×482 窗口 id
```

坐标点击成功时常见返回 `window_not_focused`，因为点击已生效并新建了窗口；此时不要重试，直接 `list-windows` 取新窗口。

### 6.3 已踩到的坑

1. `click --element-index` 带 `--restore-window` 返回 `element_not_found`：索引在前台切换后过期，必须先重新 `get-app-state`。
2. 功能子窗口里点「卸载详情」：`action_timeout`，AX 树无变化；随后坐标点击返回 `window_not_focused` 且未出现详情。结论：该按钮需要在前台窗口内用真实坐标点击，或详情是独立 sheet，需要更长时间等待。
3. 子窗口关闭用 `close button`（不是 Cmd+W，系统快捷键被阻止）。
4. 窗口位置会变化（主窗口曾从 364,266 移到 519,143），因此只用 window-local 坐标，不用屏幕坐标。

## 7. 回家继续的 Checklist

按顺序执行，每完成一项在 `openspec/changes/.../tasks.md` 勾选。

- [ ] 7.1 启动：`launch-app com.tencent.Lemon`，确认主窗口 1000×618
- [ ] 7.2 隐私清理：入口 + 扫描结果（浏览器历史/缓存/表单）
- [ ] 7.3 开机启动项管理：列表、开关、状态标识
- [ ] 7.4 磁盘空间分析：扫描结果、分类视图、是否可下钻
- [ ] 7.5 柠檬精选：页面结构（是否外链/是否可安装）
- [ ] 7.6 相似照片：添加一个测试目录（含 3 组相似图）→ 扫描 → 分组 → 勾选
- [ ] 7.7 重复文件：添加测试目录（含 3 组重复文件）→ 扫描 → keeper 规则 → 勾选
- [ ] 7.8 应用卸载详情：选中一个测试 App 的「卸载详情」，记录关联文件与残留
- [ ] 7.9 首页「开始扫描」：智能扫描的中间态与结果页
- [ ] 7.10 菜单栏状态项与设置页（若存在）
- [ ] 7.11 更新调研文档：补截图、补文案、补与 PureMac 的对比结论

### 7.1 测试素材建议

```zsh
mkdir -p /tmp/lemon-research/photos /tmp/lemon-research/dups
# 生成 3 组相似图与 3 组完全重复文件，避免扫描到用户真实目录
```

使用 `/tmp/lemon-research` 作为添加文件夹的目标，不选 `~/Pictures`、`~/Documents` 等真实目录。

## 8. 安全与隐私

1. 调研期间不点击清理、卸载、删除、强退等破坏性按钮。
2. 添加文件夹只选 `/tmp/lemon-research` 等临时目录。
3. 截图会带出本机应用名与大文件名；提交前确认不含账号、密钥、聊天内容。
4. 不复制柠檬的任何代码或资源；调研仅作功能对照。
5. 前台操作结束立即把前台切回 Orca：

```zsh
osascript -e 'tell application "Orca" to activate'
```

## 9. 与 PureMac 的初步对比

| 维度 | 腾讯柠檬 5.3.9 | 本项目 PureMac | 结论 |
| --- | --- | --- | --- |
| 导航 | 首页工具网格 → 独立子窗口 | 单窗口 + 左轨导航 | 柠檬入口更轻，但多窗口切换多；PureMac 保持单窗口更适合清理工作流 |
| 大文件 | 扫描后按大小分组、可预览、分类 tab | 阈值/时间/目录可配，结果统一表格 | 可借鉴「按大小分组 + 折叠」；PureMac 保留阈值配置 |
| 重复文件 | 先加文件夹再扫描 | 先选扫描根再扫描 | 一致；PureMac 需要补 keeper 徽标 |
| 相似照片 | 支持系统照片库 | 未实现 | 不在当前范围，记录为差距 |
| 应用卸载 | 三列可排序 + 卸载详情 | 应用列表 + 高置信/人工核对 | PureMac 的残留分级更细；可借鉴「上次打开时间」列 |
| 隐私清理 | 有 | 未实现 | 差距，记录 |
| 开机启动项 | 有 | 未实现 | 差距，记录 |
| 磁盘空间分析 | 有（可视化） | 未实现 | 差距，记录 |
| 安全模型 | 默认不勾选、清理前确认 | 默认零选中、废纸篓优先、永久删除二次确认 | PureMac 更保守，保持 |
| 广告 | 首页与子窗口底部广告条 | 无 | 不借鉴 |

## 10. 未完成与待确认

- 隐私清理、开机启动项、磁盘空间分析、柠檬精选：仅有入口名称，未进入。
- 相似照片与重复文件：只有入口页，未走完扫描流程。
- 应用卸载详情：按钮点击失败，未确认详情形态。
- 设置页与菜单栏：未确认是否存在、能否配置。
- 智能扫描：未执行，不知道是否包含清理项选择。
