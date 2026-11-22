---
name: build-desktop-pet-scene
description: 重建 BongoCat / Live2D 桌宠的透明场景资产，让动态猫、鼠标垫和键盘直接悬浮在壁纸上。适用于去白桌、修鼠标垫/键盘轮廓、补圆角、替换键鼠素材、处理透明背景与实机验收。
allowed-tools:
  - bash(git:*)
  - bash(swift:*)
  - bash(./Build/build.sh:*)
  - bash(./Build/package-release.sh:*)
  - bash(uname:*)
  - bash(/usr/bin/screencapture:*)
  - bash(/usr/bin/sips:*)
  - bash(/usr/bin/find:*)
  - bash(/usr/bin/grep:*)
  - read
  - edit
  - write
  - glob
  - grep
when_to_use: |
  当用户要求修改 BongoCat 桌宠场景、去掉白色桌面、让猫和键鼠悬浮、修鼠标垫或键盘缺角、替换桌宠背景素材、检查截图为啥糊/缺边时使用。
  典型触发：“把白桌去掉”“鼠标垫圆角太难看”“键盘缺了两个角”“用这张素材做背景”“为什么截图放大了还是糊”。
  不适用：只改菜单/设置/快捷键，或与 Live2D 场景无关的桌面宠物功能。
argument-hint: "<reference-image-or-scene-change>"
context: inline
---

# 重建桌宠透明场景

## 目标

在 **不替换动态猫** 的前提下，重建 `bongocat-standard` 的透明背景，让鼠标垫、键盘、猫都完整悬浮在壁纸上，并用原生窗口截图验收。

完成时必须同时满足：

- 鼠标垫四角完整、有明确圆角，不是尖角梯形或方块
- 键盘四角完整，键帽和外轮廓都没有被画布裁掉
- 白桌、桌线、分离阴影全部消失
- 动态猫、眨眼、视线、鼠标按键和打字反馈仍可使用
- 原生 280×170 实机截图通过，不靠 3× 放大“装清晰”
- 旧素材和 Git 回退分支保留

## 核心原则

1. **以官方 612×354 坐标为唯一基准。** `app.js` 的 `scene`、`background.clean.png`、`keyLayer` 都按 612×354 设计，不要另起一套画布比例。
2. **猫必须保持动态。** 用户给的完整场景图里通常已经把猫画死；直接当背景会和 Live2D 猫叠影。只取图中的键鼠，不取猫。
3. **键鼠要当独立美术资产处理。** 不要从官方 `background.png` 做连通域蒙版硬抠，它本身就在画布边界裁掉了键盘底边和鼠标垫左端。
4. **先看原生像素，再看放大图。** 3× 最近邻只能用于内部排查，不能当验收图；验收图用原生截图或 2× Lanczos。
5. **保留可回退版本。** 改动前确认 `backup/pet-before-noplate` 等回退分支；素材另存版本号，不覆盖官方 `background.png`。

## 工作流

### 1. 锁定基线与问题来源

```zsh
cd /Users/zhaojian/code/MacAppControlDeck
git status --short
git branch --list 'backup/*'
```

先确认三件事：

- `background.clean.png` 当前尺寸与 alpha bbox
- 窗口实际尺寸、坐标、window id
- 问题来自素材本身，还是截图缩放

检查素材边界：

```zsh
/usr/bin/sips -g pixelWidth -g pixelHeight \
  Sources/MacAppControlDeck/Modules/Pet/Resources/live2d/bongocat-standard/resources/background.clean.png
```

如果 alpha bbox 已经贴到画布底边或左边，先判定为 **源素材裁切**，不要先去怀疑截图。

### 2. 让用户给完整键鼠参考图

优先让用户提供一张“鼠标垫和键盘完整、无遮挡或少遮挡”的图。它可以是概念稿，但必须清楚：

- 鼠标垫四角都是圆角
- 键盘四角都在画面内
- 键帽文字、行数、键盘厚度可见

拿到图后不要整图直接用。先检查它是否包含猫、水印、桌面背景。

### 3. 生成“只有键鼠”的素材

用图像编辑工具，以用户参考图为输入，明确写：

- 只保留鼠标垫和键盘
- 去掉猫、猫爪、猫头、水印
- 鼠标垫四角完整圆角
- 键盘四角完整圆角，所有字母/数字/符号键帽保留
- 被猫挡住的区域按原透视补全
- 背景纯亮绿 `#00FF00`
- 不把绿色带入物体，不保留大面积投影
- 输出保持横版比例

生成后必须实际读图确认：

- 没有猫残留
- 没有水印
- 键盘四角都在
- 鼠标垫四角都在
- 不是被简化成无字键盘

> 透明背景不要直接让模型输出。实测“透明背景”经常返回黑底或半透明假象。纯绿底更稳定，后面用 alpha 抠。

### 4. 抠绿与去绿边

不要只按颜色阈值一刀切。正确顺序：

1. 用绿色占优条件生成 alpha：`g > 120` 且 `g > r*1.8` 且 `g > b*1.8`
2. 对 alpha 做约 0.5px 高斯羽化
3. 对边缘绿色溢出做去污染：`g > max(r,b)+6` 时把绿色压回 `(r+b)/2`
4. 在浅灰、深灰、壁纸三种底色上各看一遍边缘

关键检查：鼠标垫底部、键盘外轮廓、圆角处不能有绿边或灰绿描边。

### 5. 映射回 612×354

用“整张键鼠素材 + 全局仿射”最稳，不要分别缩放两个物体会破坏相对位置。

本次验收通过的一套参数：

| 项 | 值 |
| --- | --- |
| 源素材尺寸 | 1852×1273 |
| 源内容 bbox | `(221,730)-(1540,1170)` |
| 场景尺寸 | 612×354 |
| 横向缩放 | `0.4170` |
| 纵向缩放 | `0.3886` |
| 贴图偏移 | `(-82,-102)` |
| 最终 alpha bbox | `(4,176)-(572,354)` |

落地后用 `background.clean.png`，保留官方 `background.png` 不动。

### 6. 构建、安装、抓原生窗口

```zsh
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
./Build/build.sh
osascript -e 'tell application "MacAppControlDeck" to quit' || true
sleep 2
ditto BuildOutput/MacAppControlDeck.app /Applications/MacAppControlDeck.app
open -a /Applications/MacAppControlDeck.app
sleep 4
swift /tmp/listwin2.swift
```

用 CGWindowList 查当前 owner 为 `Mac 应用快捷控制台` 的窗口，不要硬编码旧 window id。

截图：

```zsh
/usr/sbin/screencapture -x -l<windowId> /tmp/noplate_window.png
```

**等 3 秒再拍。** 猫每 5 秒有一次约 0.18 秒的眨眼帧，首拍经常正好闭眼，看起来像“眼睛丢了”。

### 7. 实机验收

必须看四张图：

1. 原生 1× 截图：确认整体比例、边距、有没有贴边
2. 2× Lanczos：交付图，确认键鼠轮廓和圆角
3. 键盘右下角局部放大：确认四角完整
4. 鼠标垫左端局部放大：确认左侧圆角和边缘没有绿边

不要用 3× 最近邻判断清晰度；它只会把 1px 瑕疵放大成锯齿。

### 8. 更新验收图并交付

最终图固定写这两个位置：

- `Docs/design/desktop-pet-bongocat-noplate-native.png`：原生 280×170
- `Docs/design/desktop-pet-bongocat-noplate.png`：2× 验收图，560×340

交付时说明：

- 问题是不是源素材裁切，不是截图
- 键鼠来自哪张参考图，猫是否保留动态
- 是否做了放大，放大倍率是多少
- 回退分支名

## 关键坑

### 官方素材本身就被裁

`bongocat-standard/resources/background.png` 是 612×354，键盘底边和鼠标垫左端在源图里就被画布切断。不要试图靠“少放大一点”补回来，缺的是像素本身。

### 概念图不能整张当背景

概念稿、AI 图里的猫是画死的。整张当背景会出现：

- 静态猫和动态猫叠影
- 眨眼时两张脸不同步
- 鼠标/猫爪位置对不上

正确做法：只取键鼠，猫继续用 Live2D。

### 手绘补角一定会被看出来

小圆角端帽、椭圆半圆端帽、直边端帽、纯渐变方块都试过，问题分别是像气泡、像瓶口、接缝明显、太几何。最后通过的是 **直接用完整键鼠素材重新裁**，不是手画。

### 键盘替换会破坏按键高亮对齐

`left-keys/KeyA.png` 等按键高亮图是按 **官方键盘像素坐标** 预渲染的整张 612×354 图。换掉键盘后，高亮和猫爪落点会偏到别的键上。

处理优先级：

1. 只想修轮廓：优先保留官方键盘，只补外轮廓
2. 必须换整把键盘：接受高亮暂不对齐，或按新键盘逐键重映射
3. 不要把“视觉通过”误当成“按键反馈也通过”

### `keyLayer` 是猫爪和蓝键覆盖层，不是键盘底板

`keyLayer` 里的 `KeyA.png` 等资源本身就是整张画布大小的 **白色猫爪 + 蓝色按键高亮**。把 `keyLayer.visible` 设为 `false` 会同时去掉按键反馈和爪子的按下动作，并不会让背景键盘消失。不要用它来“规避错位”。

### 先确认宿主架构再安装

打包前执行：

```zsh
uname -m
```

arm64 包在 Intel Mac 上会直接报 `The application cannot be opened because it has an incorrect executable format`。开发机是 x86_64 时，测试包用：

```zsh
./Build/package-release.sh x86_64
```

不要拿 arm64 产物覆盖 `/Applications`，否则旧版也会被替换成打不开的包。

### 0.94 缩放会让整体小 6%

当前 `scene` 有 `Math.min(w/612,h/354)*0.94`，用来留安全边距。用户如果觉得“变小了”，改缩放前必须先确认不会再把边缘贴回去。

### 截图坐标会变

窗口 id、PID、X/Y 每次重启都会变。必须用 CGWindowList 重新查，不能复用上次的 `-l240`。

## 验收清单

- [ ] 鼠标垫四角完整、圆角自然
- [ ] 键盘四角完整、键帽不缺
- [ ] 没有白桌、桌线、分离阴影
- [ ] 原生 280×170 截图不贴边
- [ ] 猫眼睛正常，不是眨眼帧
- [ ] 2× 验收图已更新
- [ ] 官方 `background.png` 未覆盖
- [ ] 回退分支可用
- [ ] 已知按键高亮风险已向用户说明或已重映射

## 发布收尾

场景通过用户验收后，按顺序做：

1. **版本**：改 `Build/Info.plist` 的 `CFBundleShortVersionString` 与 `CFBundleVersion`。
2. **合规**：确认上游许可证；`THIRD_PARTY_NOTICES.md` 写清上游地址、固定提交、引入目录和改动；安装包内带 `Resources/Licenses/<upstream>-LICENSE.txt`。
3. **OpenSpec**：把活动变更移到 `openspec/changes/archive/YYYY-MM-DD-<change-id>/`，同步 `openspec/specs/<capability>/spec.md`，勾完 `tasks.md`。
4. **发布说明**：在 `Docs/releases/v<version>.md` 记录下载表、安装、本版内容、系统要求、已知限制和 SHA256。
5. **选择性提交**：只 `git add` 运行时代码、背景、验收图、Skill、OpenSpec、许可证和发布说明；不要 `git add -A`，未采用的 `v7`、`v8`、`hijiki`、`tororo` 和实验 mp4/py 不进发布提交。
6. **双架构包**：`./Build/package-release.sh arm64` 和 `./Build/package-release.sh x86_64`；复核 `file`/`lipo -info` 与 `SHA256SUMS.txt`。
7. **备份分支**：`backup/pet-before-noplate` 只留本地，明确不 `push`；推送前用 `git ls-remote --heads origin` 确认远端没有同名分支。
8. **推送与 Release**：先推 `main`，再打 annotated tag，最后用 GitHub API 或 Release 页面上传 zip/dmg/SHA256SUMS。

