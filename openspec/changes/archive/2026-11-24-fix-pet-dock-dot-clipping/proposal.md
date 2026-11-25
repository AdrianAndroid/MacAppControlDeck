# Change: 修复桌宠快捷栏运行圆点被裁切

## Why

`add-pet-dock` 交付后真机发现：运行中的绿点在胶囊底边被切掉一半。

原因是上下内边距写在了**窗口高度**上，而 `GeometryReader` 的内容是顶部对齐的——内容自己没吃到垂直 padding，胶囊实际只有图标高度。绿点为了压在图标右下角外沿而溢出 1pt，正好撞在 `.clipped()` 的边线上。

## What Changes

1. `PetDockView`：内容的 `frame` 显式给定 `height: metrics.height`，图标在条内垂直居中，胶囊随之撑满条高，裁剪区域覆盖整条。
2. `PetDockMetrics.paddingY`：6 → 8，条高变为 `图标 + 16`（小 46 / 中 52 / 大 58），绿点下方仍留 7pt。
3. 左右内边距维持 4pt，条宽「随图标数量收缩并相对桌宠居中」等行为不变。

## Capabilities

- `desktop-pet`：快捷栏的垂直内边距与运行圆点可见性。

## Impact

- 只改 `Modules/Pet/PetDock.swift` 的 `paddingY` 与 `PetDockView` 的布局 frame；不动手势、排序、数据来源与窗口位置。
- 归档的 `2026-11-24-add-pet-dock` 保持原始记录（6pt + 裁切），修正记录在本变更。

## Non-goals

- 不调整图标尺寸、间距、排序规则、拖动行为。
- 不为圆点增加新的显示开关或位置配置。
