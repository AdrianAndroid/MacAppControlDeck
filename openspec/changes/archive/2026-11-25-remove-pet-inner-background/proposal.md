# 去掉副屏桌宠卡片内层背景

## 背景

横屏副屏在「显示模块边框」开启时，桌宠框已经由 `#frame[data-frames="on"] .pet-dock` 绘制一层 1px 外框；而内层 `.pet-box` 又额外绘制了 `background: rgba(255,255,255,.035)` 与 `border: 1px solid rgba(255,255,255,.08)`。两层叠加后视觉上出现「两个边框」，且底栏比其他模块多一块半透明填充，显得重复、厚重。

## 目标

- 桌宠卡片只保留一层外框，与时钟 / 月历 / 倒计时 / 天气模块保持一致的边框观感。
- 桌宠卡片内部不再有独立背景层，宠物与文字直接落在底栏底板上。
- 不改变桌宠游走、换宠、配置下发或边框开关/强度的任何逻辑。

## 范围

仅调整 `Panel/Screen/index.html` 中 `.pet-box` 的 CSS；不动任何数据接口、Swift 代码与 PC 端设置。

## 实现

1. 删除 `.pet-box` 的 `background` 与 `border` 声明，只保留 `position: relative; flex: 1 1 auto; overflow: hidden`。
2. 外框统一由 `.pet-dock` 承担（边框开关关闭时自然无框，开启时为单层 1px 圆角框）。
3. 未 bump 页面版本号：页面本身带 `Cache-Control: no-store`，覆盖安装后即生效。
