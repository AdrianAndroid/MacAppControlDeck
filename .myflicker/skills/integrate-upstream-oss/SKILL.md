---
name: integrate-upstream-oss
description: 把上游开源 macOS 项目的功能整文件 vendor 进来，用薄适配层接入现有模块，并以真实产物验收，而不是手写重实现。
allowed-tools:
  - bash(git:*)
  - bash(swift:*)
  - bash(./Build/build.sh:*)
  - bash(defaults:*)
  - bash(pgrep:*)
  - bash(pkill:*)
  - bash(open:*)
  - bash(/usr/bin/find:*)
  - bash(/usr/bin/sips:*)
  - bash(/usr/sbin/screencapture:*)
  - read
  - edit
  - write
  - glob
  - grep
when_to_use: |
  当用户想把某个开源项目/竞品的功能接进本项目，或说“按上游源码来”“不要手写”“vendor 这个仓库”“把某某开源软件集成进来”“移植这个功能”“重新学上游实现”时使用。
  典型触发：把 macshot 的截图/录屏整体接进来；把这个 GitHub 项目的窗口管理模块集成进来；别再自己写，直接用上游实现。
  不适用：只改本项目已有代码的小 bug、纯 UI 文案调整、没有上游可复用的独立新功能。
argument-hint: "<upstream-repo-or-path> <target-module> [license]"
arguments:
  - upstream: 上游仓库 URL、本地 clone 路径，或已存在的 /tmp/<name> 目录
  - target_module: 本仓库中承接功能的模块，例如 capture、remote、MacShotKit
  - license: 上游许可证（可选，默认先读取 LICENSE；GPL 项目要求整体兼容分发）
context: inline
---

# 集成上游开源项目

## 目标

把一个上游开源项目里**已经验证过的功能实现**原样搬进本仓库，通过薄适配层连接现有模块边界，并用真实产物证明它工作。禁止用自写代码去“模仿”上游界面。

完成时必须有：

- 上游 commit 锁定，来源与许可证写入 `THIRD_PARTY_NOTICES.md`
- 上游源码整文件位于 `Sources/<Kit>/Upstream/<Domain>/`，核心逻辑未改写
- 一层薄适配器负责 delegate/callback 与模块生命周期
- 被替代的 Legacy/自写实现已删除
- 每个承诺入口都有产物级验证记录（尺寸、内容、时长、落盘位置）
- 更新 `Docs/architecture/UPSTREAM_PORTING.md`
- 构建通过，提交并推送（用户已授权）

## 输入

- `$upstream`：上游仓库 URL 或本地路径
- `$target_module`：本项目承接模块
- `$license`：上游许可证，未给则读取上游 `LICENSE`

## 步骤

### 1. 锁定上游与许可证

```zsh
git clone "$upstream" /tmp/upstream-$(basename "$upstream" .git)  # 若尚未 clone
git -C /tmp/<upstream> rev-parse HEAD
head -20 /tmp/<upstream>/LICENSE
```

记录 commit SHA、许可证、允许分发方式。若上游为 GPL，确认本项目整体分发方式兼容，并在 `THIRD_PARTY_NOTICES.md` 保留来源与目录清单。

**Success criteria**：
- [ ] 有明确 commit SHA
- [ ] 许可证已确认，且与项目分发方式不冲突
- [ ] 已决定要搬的目录范围（不是“先搬一个文件试试”）

**Artifacts**：上游路径、commit SHA、许可证、目标目录清单

### 2. 画“入口 → delegate/callback”调用图

从用户入口倒推，不要从上游内部结构开始读：

- 菜单/热键 → 哪个 controller / view / window
- 该 controller 的 delegate 协议有哪些必需方法、哪些有默认实现
- 每个回调期望宿主做什么：保存、导出、OCR、录制、滚动、权限
- 上游在回调里读取了哪些 UserDefaults 键、输出路径、环境假设

把结论写成表：

| 本项目入口 | 上游类型/方法 | 宿主需要实现 |
| --- | --- | --- |

**Success criteria**：
- [ ] 所有承诺入口都能映射到具体上游方法
- [ ] 已列出 delegate 协议的完整方法集
- [ ] 已列出上游依赖的配置键/路径

**Artifacts**：入口映射表、delegate 方法清单

### 3. 整文件 vendor 到 Upstream 目录

原则：**一个功能域一次搬完整文件集**，优先零修改。

```zsh
mkdir -p Sources/<Kit>/Upstream/<Domain>
cp /tmp/<upstream>/<path>/{A.swift,B.swift,C.swift} Sources/<Kit>/Upstream/<Domain>/
swift build -c release
```

只处理必要的编译问题：缺失的 `L()`/日志垫片、重名类型、平台可用性。不要给上游核心逻辑加“本项目兼容分支”。

**Success criteria**：
- [ ] `swift build -c release` 通过
- [ ] 上游文件保持原样，例外处集中记录
- [ ] 没有把上游 App 外壳（菜单栏 App、更新器、独立设置 App）一起搬进来

**Artifacts**：`Upstream/<Domain>/` 文件集、编译结果

### 4. 写薄适配层

新建或扩展一个 coordinator/host，例如：

```swift
@MainActor
final class OverlayCoordinator: NSObject, <UpstreamDelegate> {
    // 生命周期：持有 controller / panel / 窗口数组
    // 回调翻译：保存、录制、OCR、滚动、权限
    // 产品语义：输出目录、文件名、UserDefaults 键、提示文案
}
```

适配层只做翻译和生命周期管理：

- 上游类型不泄露到其他模块
- 多屏/多窗口/取消/连按热键由适配层管理
- 行为本身调用上游，如拼接、帧匹配、录制、导出

**Success criteria**：
- [ ] 上游 delegate 必需方法全部实现
- [ ] 本项目模块边界未被打破
- [ ] 适配层没有重新实现上游已有算法
- [ ] `swift build -c release` 通过

**Artifacts**：适配层文件路径

### 5. 删除被替代的实现

搜索并删除旧的 `Legacy*`、自写 controller、重复算法。保留只能作为兼容垫片且明确标注的少量代码。

**Success criteria**：
- [ ] `grep -rn "Legacy<Domain>" Sources` 无调用方
- [ ] 删除后完整构建通过
- [ ] 没有两套实现同时可被触发

**Rules**：宁可删错再补，也不要留下双实现；双实现会造成“看起来能用、行为随机”的假象。

### 6. 产物级端到端验收

先构建 App：

```zsh
./Build/build.sh
pkill -f "<App>.app/Contents/MacOS/<App>" || true
open BuildOutput/<App>.app
```

按入口逐个验证，只看真实产物：

```zsh
/usr/bin/sips -g pixelWidth -g pixelHeight "<image>.png"
ls -l <expected-output-dir>
/usr/bin/find ~/Library/Application\ Support/<App> -name '*.mp4' -newermt '-10 minutes'
```

可用合成事件做 UI 冒烟：`CGEvent` 发全局热键、拖选区、点工具栏/HUD，再用 `screencapture` 核对状态。

**注意**：合成键盘事件只稳定送达当前活跃 App 的 key window；非激活面板收不到合成 `Esc/Return` 是测试限制，不要误判为产品 bug。鼠标事件可用于验证按钮位置。

每个入口的最低证据：

- **截图**：像素尺寸 = 选区 × backingScale，内容非纯色/非透明，文件体积合理
- **全屏**：尺寸等于屏幕像素尺寸
- **录制**：文件存在、时长接近实际、编辑器可打开、HUD/边框不在画面里、承诺的落盘目录有文件
- **滚动**：拼接高度显著大于选区，固定侧栏/导航栏不重复
- **多屏**：每屏一个覆盖层，跨屏选区能拼成一张图
- **延时/取消**：倒计时出现，Esc 取消后无输出

**Success criteria**：
- [ ] 每个承诺入口都有至少一张产物或一段视频作为证据
- [ ] 所有尺寸/时长/路径符合预期
- [ ] 没有“界面成功但产物为空”的情况

**Human checkpoint**：如果发现上游行为与产品文档冲突（例如上游把 take 留在应用支持目录，而产品承诺 `~/Movies`），先按产品承诺补归档/发布逻辑，再继续验收。

### 7. 更新文档与许可证

- `THIRD_PARTY_NOTICES.md`：上游 URL、许可证、已引入目录、适配层
- `Docs/architecture/UPSTREAM_PORTING.md`：本次 commit、迁移范围、验收结果、已知缺口
- `README.md`：开发文档链接

**Success criteria**：
- [ ] 第三方来源可追溯
- [ ] 集成手册包含本次 commit 与验证结论
- [ ] README 能索引到手册

### 8. 提交并推送

```zsh
git status --short
git add -A
git commit -m "feat(<scope>): vendor upstream <name> (<domain>)"
git push origin HEAD
```

提交信息写清上游 commit 与迁移范围；不要 force push；不要提交 `.build/`、`BuildOutput/`、临时文件。

**Success criteria**：
- [ ] 工作区干净
- [ ] 远端分支包含本次提交
- [ ] 提交信息能定位上游来源

## 硬约束

- 不要用“界面看起来像”证明成功，必须验证产物。
- 不要重写上游核心算法；需要差异时只改适配层。
- 不要保留两套实现。
- 不要假设上游会写到你承诺的输出目录；完成回调里显式归档。
- 不要为了“兼容”给上游文件加分支；集中到适配层。
- GPL 上游：保持整体 GPL 分发与来源声明。

## 常见坑

- SPM 测试 bundle 可能无法弱链接 ScreenCaptureKit，`swift test` 失败不等于 App 失败。
- 上游 UserDefaults 键与本项目设置键不同，必须双向同步，否则界面显示与实际行为不一致。
- 热键连按会叠出多层 overlay，进入前先 dismiss 上一组。
- 非激活面板是上游常见设计，测试不要用 `NSApp.isActive` 判断成功。
- 文件生成不等于内容正确：纯色/透明图通常体积异常小。
