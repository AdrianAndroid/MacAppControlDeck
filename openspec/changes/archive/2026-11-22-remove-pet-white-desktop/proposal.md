# remove-pet-white-desktop

## Why
standard 桌宠的 `background.png` 下半部分自带一整块白色桌面和横贯画面的黑色桌线，在透明窗口里形成明显的方形白板和第二条桌线，观感生硬。

## What Changes
- 从官方 `background.png` 派生透明背景 `background.clean.png`：只保留鼠标垫和完整键盘，清除白色桌面、方形边缘和斜向桌线。
- standard 场景改用 `background.clean.png`；模型、键位图、canvas 投影和输入逻辑保持不变。
- 透明区域直接透出桌面壁纸，不再有白色托板；键盘和鼠标垫沿用自身描边与阴影。

## Capabilities
- `pet-live2d-bongocat`：桌面来源改为透明键鼠层，移除白色桌面。

## Impact
- `Resources/live2d/bongocat-standard/resources/background.clean.png`
- `Resources/live2d/app.js` 中 standard 背景加载路径
- 不新增用户可见入口，沿用 `pet.open`
- 回退点：本地分支 `backup/pet-before-noplate` 指向提交 `e20b882`
- 发布合规：已确认 BongoCat 上游为 Apache-2.0，`THIRD_PARTY_NOTICES.md` 与安装包内许可证原文随版本补齐

## 非目标
- 不改猫模型、窗口比例和输入语义。
- 不新增设置开关或重做 UI。
- 不逐键重映射官方键位高亮坐标；该偏差作为已知问题在发布说明披露。
