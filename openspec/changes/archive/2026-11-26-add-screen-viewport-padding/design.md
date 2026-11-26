# 设计：副屏视口铺满与可调内边距

## 背景

改动前 `#frame` 同时存在两层外边距：

1. 大屏媒体查询 `@media (min-width: 640px) and (min-height: 520px)` 把 `#frame` 从 `inset: 0`
   改成 `inset: 2.6u`，并加圆角与描边；
2. `#frame` 自身 `padding` 写死 `3u`（再叠加 safe-area）。

所以内容边缘到视口边缘约 `5.6u`，在 1788×855 的桌面窗口里接近 36px，看似"没有填满"。

## 方案

- `#frame` 保持 `position: fixed; inset: 0`，删除大屏 inset 规则。
- 内边距改为变量：

  ```css
  --vp-top: 0px; --vp-right: 0px; --vp-bottom: 0px; --vp-left: 0px;
  padding: calc(env(safe-area-inset-top, 0px) + var(--vp-top)) ...;
  ```

  safe-area 仍然叠加，因此 iPhone 刘海/底部仍安全；桌面与平板默认完全贴边。
- `ScreenFrameConfig` 增四个 Int 字段，范围 0–120px，`normalized`/设置层双重收敛；
  `/api/screen/frame` 原样下发，`applyScreenFrame` 写 `--vp-*`。
- 设置页用四个 `Stepper`（步长 2px）+「归零」，保存即 `ScreenEventHub.notifyChange()`，
  副屏下一次事件轮询整页重载后应用。

## 取舍

- 为什么用 px 而不是 `u`：`u` 随屏幕尺寸缩放，用户在笔记本上调好的留白到手机上会变样；
  px 是浏览器 CSS 像素，跨设备观感一致，也便于和设计稿对齐。
- 为什么默认 0：需求是"铺满视口"；留白由用户显式加，避免再次出现"看起来没填满"。
- 为什么不保留大屏圆角浮动边框：它本身就是第一层留白来源；走查外边框仍然负责画视口边界。
