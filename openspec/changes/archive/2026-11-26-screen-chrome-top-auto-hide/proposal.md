# 副屏控制条移到顶部并恢复自动隐藏

## 背景

副屏（手机）的刷新 / 全屏控制条一直挂在屏幕上挡住内容。此前为了「触屏 5 秒后点不到按钮」，在 `keepUIVisible()` 中对 `(pointer: coarse)` 设备直接 return、取消了自动隐藏定时器。副屏正是触屏设备，于是控制条常驻不消失。同时控制条原本固定在屏幕底部 `bottom`。

## 目标

- 控制条不再长期遮挡副屏：显示后 5 秒自动隐藏，触屏设备也一样。
- 需要时点按屏幕任意处即可再次唤出控制条。
- 控制条弹出位置改为屏幕顶部。

## 范围

仅调整 `Panel/Screen/index.html` 的控制条 CSS 与 `keepUIVisible()`；不改按钮功能、配置下发与其他页面逻辑。

## 实现

1. `.chrome` 从 `bottom: env(safe-area-inset-bottom)+4u` 改为 `top: env(safe-area-inset-top)+2u`，隐藏态 transform 改为 `translate(-50%, -2u)`，从顶部滑入。
2. `keepUIVisible()` 删除 `coarsePointer` 常驻例外，所有设备统一 5 秒后移除 `ui` class。
3. 保留首次进入 `setTimeout(showUI, 400)`：进入后短暂展示提示、随后自动消失。
4. 触屏 `pointerdown` 唤出逻辑不变。
