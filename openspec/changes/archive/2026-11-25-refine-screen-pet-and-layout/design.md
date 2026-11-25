# Design: 重做副屏三栏底栏与桌宠

## 页面结构

横屏 `#frame .stage` 使用 3 列 × 2 行网格：

```text
.col 内部：
  主区 flex: 1 1 auto; min-height: 0
  底栏 flex: 0 0 var(--dock-h); height: var(--dock-h)

左栏：时钟主区 + 桌宠框
中栏：月历主区 + 倒计时框
右栏：天气主区 + 城市/更新时间信息区
```

`--dock-h` 默认 `120px`，矮横屏断点使用固定 `92px`，保证桌宠与倒计时同为固定高度且同一水平基线。

## 布局约束

- 三栏都 `height: 100%`，不允许整页滚动。
- 主区顶部对齐：删除三栏顶部 kicker 与分隔线，时钟表盘居中，月历标题贴主区顶部。
- 月历不再 `margin:auto`；倒计时卡从 `.cal-stack` 中独立为底栏元素。
- 天气城市名与更新时间移入右栏底栏，不再占用天气主区顶部。

## 桌宠实现

- 桌宠素材为本地内联 SVG 的两个走路帧，不请求外网。
- 三只宠物：`cat`（像素猫）、`dog`（小狗）、`robot`（机器人）。
- 游走逻辑使用时间间隔更新位置，碰到左右边界掉头；`prefers-reduced-motion` 下居中静止。
- 页面隐藏时停止游走帧更新与随机切换计时，恢复可见后重新排程。

## 桌宠配置

localStorage 键：

```text
deck.screen.pet.mode      fixed | random
deck.screen.pet.id        cat | dog | robot
deck.screen.pet.interval  30 | 60 | 300 | 900
deck.screen.pet.nextAt    下次随机切换的毫秒时间戳
```

随机切换使用洗牌队列：每轮包含全部宠物且不重复；下一轮重新洗牌并保证与上一轮最后一只不同。手动「立即换一只」重置倒计时。

## 刷新按钮

统一 `refreshAll()` 调用时间、天气、倒计时和外观设置刷新；点击期间按钮显示忙态，完成后显示「已刷新」1.2 秒。控制条在刷新期间保持可见。
