# 设计：让运行圆点完整显示

## 问题

```
错误（胶囊 = 图标高）
┌──────────────────────────┐ ← 窗口高 = 图标 + 12
│ ▣ ▣ ▣ ▣                  │ ← 内容顶部对齐，高 = 图标
└──────────────────────────┘ ← 胶囊底 = 图标底，绿点溢出 1pt 被 clipped 切掉
   （下面 12pt 是空的窗口区域，不是胶囊）
```

`.frame(height:)` 加在 `GeometryReader` **外面**时，只改变窗口大小，不会让里面的胶囊变高；`GeometryReader` 的子视图永远按 top-leading 摆放。左右 padding 之所以"看起来生效"，是因为胶囊宽度被显式 `frame(width:)` 撑开了。

## 改法

```swift
HStack(spacing: spacing) { … }
    .padding(.horizontal, paddingX)
    .frame(width: contentWidth, height: metrics.height, alignment: .leading) // 撑满
    .offset(x: clampedOffset(maxScroll))
    .frame(width: geo.size.width, height: metrics.height, alignment: .leading)
    .clipped()
```

- `Alignment.leading` 的垂直分量是 `.center`，图标因此在新高度里垂直居中
- 胶囊（`.background`）随内容撑到 `metrics.height`
- `.clipped()` 的裁剪范围同样变成整条，绿点即使溢出图标 1pt 也不会被切

## 数值

`paddingY = 8`，条高 = 图标 + 16：

| 档位 | 图标 | 条高 | 绿点下方余量 |
| --- | --- | --- | --- |
| 小 | 30 | 46 | 7pt |
| 中 | 36 | 52 | 7pt |
| 大 | 42 | 58 | 7pt |

左右仍是 4pt，条宽收缩/居中的逻辑不受影响。
