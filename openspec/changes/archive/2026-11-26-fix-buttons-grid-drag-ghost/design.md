# 设计：按钮拖动浮层跟手

## 问题链路

```text
卡片按下
  └─ DragGesture 属于这张卡片
长按 0.5s → 进入拖动
  └─ entries 把被拖卡片换成占位视图
       └─ 卡片视图从视图树移除
            └─ SwiftUI 取消该卡片的 DragGesture
                 └─ 浮层停在 beginDrag 时的最后位置
```

## 修复

```text
LazyVGrid（稳定容器）
  └─ highPriorityGesture(DragGesture(minimumDistance: 0))
       ├─ onChanged 第一次：用 startLocation 命中卡片 frame，记录 pressingID
       ├─ 0.5s 计时 / 8pt 抖动阈值 / 4pt 进入拖动
       ├─ 被拖卡片换成占位视图时，手势属于容器，不会取消
       └─ 每次 onChanged：dragLocation 更新 → 浮层跟手
```

- 手势识别从 `card` 移到 `LazyVGrid`。
- `hitButton(at:in:)` 用按下起点和 `frames` 做命中，间隙 6pt 内取最近卡片。
- 卡片右键菜单、hover、help、accessibilityAction 保持不变。
- 松手仍然只调用一次 `DeckState.moveToIndex`。

## 验证

- 系统级鼠标事件：按住 0.75 秒后水平拖动，拖动中截图确认浮层位于指针位置、占位空隙已插入。
- 点击选中、右键菜单在高优先级容器手势下仍正常。
- `swift test --filter ButtonGridReorderTests`：7 项通过。
- `./Build/build.sh` 与固定签名校验通过。
