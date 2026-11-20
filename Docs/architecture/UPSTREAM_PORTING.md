# 上游开源集成手册（以 macshot 为例）

本文记录截图/录屏模块最终成功的方式，以及为什么前面走了弯路。后续再接开源软件时，按同一套流程执行。

## 一句话结论

**不要重写上游已经做对的东西。** 把上游源码原样 vendor 进来，用一层很薄的适配器接进本项目的模块边界；验收只看真实产物（像素、文件、时间轴），不看“看起来像”。

## 为什么一开始没有这么做

回头看，前期的失败不是技术问题，而是方法和判断顺序错了：

1. **把“实现功能”当成目标，而不是“复用已验证的实现”。**
   于是按需求文档逐条手写选区、工具栏、标注、录制，界面能做到相似，但交互状态、边界条件、导出细节永远差一截。

2. **先写 UI，后验证数据。**
   截图流程曾经能弹出遮罩、能拖选区、能“保存成功”，但覆盖层根本没有安装真实截屏，导出的是透明/空白图。文件也能生成，所以看起来像成功。

3. **没有先做上游能力盘点。**
   没有在动手前回答：上游有哪些文件、哪些入口、哪些 delegate、哪些可以被原样编译？结果重复实现了上游已经成熟的部分。

4. **对许可证和体量有顾虑，但没有量化。**
   顾虑 GPL 与代码量，却没有先做一次最小 vendor 实验。实际证明：上游大量文件只依赖 Cocoa/SCKit，原样放进 SPM target 就能编译。

5. **验收标准是“能点”，不是“产物正确”。**
   没有端到端断言：图片尺寸/内容、视频时长/音画同步、滚动拼接高度、录制文件落盘位置。

一句话：**先找现成的正确答案，再写适配；不要用自写代码去猜正确答案。**

## 成功路径（可复用）

### 1. 固定上游版本

```zsh
git clone <upstream> /tmp/<upstream>
git -C /tmp/<upstream> rev-parse HEAD   # 记录到文档/提交信息
```

不要直接跟 `main` 漂移。先锁一个 commit，集成通过后再讨论升级。

### 2. 做“入口 → 回调”清单，而不是“功能 → 自写代码”清单

从用户入口倒推：

- 菜单/热键 → 上游哪个 controller / view
- 上游 controller 的 delegate 协议有哪些方法
- 每个方法期望宿主做什么（保存、OCR、录制、滚动、权限）
- 哪些方法是可选的，哪些有默认实现

macshot 的关键入口就是 `OverlayWindowControllerDelegate`。把协议抄下来逐条实现，比读十篇设计文档有效。

### 3. 整文件 vendor，不改上游实现

原则：

- 一个功能域一次搬完整文件集，不要“搬一半再补”。
- 上游文件尽量零修改；必须改时集中记录。
- 新代码只放在 `Sources/MacShotKit/Upstream/<Domain>/` 和薄适配层里。
- 删除已经被替代的自写实现，避免两套逻辑互相打架。

macshot 实际搬入：

| 目录 | 内容 |
| --- | --- |
| `Upstream/Overlay` | 截图覆盖层、工具栏、标注、弹出面板、滚动 HUD/预览 |
| `Upstream/Recording` | RecordingEngine、MP4 writer、麦克风、指针/按键 telemetry |
| `Upstream/VideoEditor` | 时间线编辑器、导出、GIF、光标/键盘叠加渲染 |
| `Upstream/Capture` | ScrollCaptureController、Stitcher、FrameMatcher、FrameAnalyzer |
| `Upstream/Windows` | CountdownView 等共享窗口 |

### 4. 用适配层连接模块边界，而不是改上游

本项目的适配层是 `Sources/MacShotKit/OverlayCoordinator.swift`：

- 实现上游 delegate，把动作翻译成本项目已有链路（`MacShotController` 保存/录制/OCR/钉图）。
- 持有上游 controller 数组、预览面板、倒计时窗口的生命周期。
- 负责“本项目语义”：输出目录、文件名模板、UserDefaults 键、权限提示文案。

适配层允许薄，但不允许“重新实现上游行为”。例如多屏拼接、远程选区、滚动帧匹配都直接调用上游代码。

### 5. 先让编译通过，再让交互通过

顺序：

1. `swift build -c release`：解决 import、重名、平台 API。
2. 单入口冒烟：区域截图能出图。
3. 多入口：全屏、窗口、滚动、录制、编辑器。
4. 边界：延时、取消、连按热键、无权限、多显示器。

编译不过时优先删本项目的重复实现，而不是给上游加兼容分支。

### 6. 端到端验收（必须看真实产物）

最低验证集：

```zsh
# 截图尺寸与内容
sips -g pixelWidth -g pixelHeight "<output>.png"

# 录屏时长/体积
ls -l ~/Movies/MacAppControlDeck/*.mp4
mdls -name kMDItemDurationSeconds "<output>.mp4"

# 滚动长图
sips -g pixelHeight "<scroll>.png"   # 明显大于选区高度
```

自动化 UI 冒烟：用 `CGEvent` 发菜单热键、拖拽选区、点击工具栏/HUD，再用 `screencapture` 核对状态。

**注意**：合成键盘事件只稳定送达“当前活跃 App 的 key window”。如果覆盖层是非激活面板且宿主 App 未激活，`Esc/Return` 的合成事件可能不生效；这是测试工具限制，不要误判为产品 bug。鼠标事件与真实点击可正常验证。

产物验收的硬标准：

- 截图：尺寸 = 选区 × backingScale，且内容非纯色/非透明。
- 录制：文件存在、时长接近实际、编辑器能打开、HUD 不在画面里。
- 滚动：高度显著增加，固定侧栏/导航栏不应重复。
- 多屏：每屏一个覆盖层，跨屏选区能拼成一张图。

### 7. 清理与记录

- 删除被替代的 `Legacy*` 实现。
- 更新 `THIRD_PARTY_NOTICES.md`（上游、许可证、具体目录）。
- 在本文件追加本次上游 commit、已知缺口、未验证项。

## 下一次接开源项目的 Checklist

- [ ] 选定上游并锁定 commit
- [ ] 许可证确认（GPL 项目整体 GPL 分发；保留版权与来源）
- [ ] 画出入口 → delegate/callback 调用图
- [ ] 找到最小可编译文件集，整文件复制到 `Upstream/<Domain>`
- [ ] 写薄适配层，不改上游核心逻辑
- [ ] 先编译，再单入口冒烟，再多入口
- [ ] 用真实产物验收（尺寸、内容、时长、落盘）
- [ ] 删除重复实现，更新第三方说明与本手册
- [ ] 提交信息写清上游 commit 与迁移范围

## 已知坑（macshot 实测）

- **SPM 测试包无法弱链接 ScreenCaptureKit**：`swift test` 会在测试 bundle 启动时失败；App 运行不受影响。只保留不依赖 SCK 的测试，或后续改用 Xcode 测试目标。
- **UserDefaults 键要对齐**：上游读写 `recordingFPS`、`recordSystemAudio`、`captureDelaySeconds` 等；本项目设置页用自己的键时，必须在启动/菜单同步时写回上游键，否则覆盖层显示与实际录制不一致。
- **覆盖层生命周期**：热键连按时必须先 dismiss 上一组 overlay，否则会叠出多层遮罩，看起来像“点击没反应”。
- **录制产物位置**：上游 take 落在应用支持目录，编辑器从中打开。若产品承诺 `~/Movies/...`，需要在完成回调里显式归档，不能假设上游会写。
- **空白截图检测**：不要只看“文件已生成”。至少检查像素尺寸和文件体积；纯色/透明图往往体积异常小。
- **非激活面板**：上游大量 UI 是 `nonactivatingPanel`，用于不抢焦点。测试时不要用“App 是否 active”判断是否成功，用窗口/产物判断。

## 本次迁移基线

- 上游：`sw33tLie/macshot`（GPL-3.0）
- 迁移范围：截图覆盖层 + 标注 + 历史/钉图/OCR 出口 + 录屏引擎 + 视频编辑器 + 滚动截图
- 适配层：`Sources/MacShotKit/OverlayCoordinator.swift`、`Sources/MacShotKit/MacShotController.swift`
- 本机验证：区域 1040×720、全屏 3456×2234、延时截图、滚动 1200×2122、MP4 落盘并自动打开编辑器
