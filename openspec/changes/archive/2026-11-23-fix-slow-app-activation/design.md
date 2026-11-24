# 设计：修复手机打开应用普遍响应慢

## 修复 1 — Dock 图标空标题误匹配

`AppControl.pressDockIcon` 遍历 Dock 子项，对每个标题做归一化后与目标应用名比对。当前条件：

```swift
guard names.contains(where: { $0 == normalized || normalized.hasPrefix($0) || $0.hasPrefix(normalized) })
```

当 Dock 子项（分隔符、空标题项）的 `normalized` 为空串时，`$0.hasPrefix("")` 恒为 true，导致任意目标都会命中这个空项。按下空项对目标应用无作用，但 `AXUIElementPerformAction` 仍返回 `.success`，函数返回 true，调用方误以为已按下 Dock 图标并进入 8 秒等待。

修复：比对前先 `guard !normalized.isEmpty else { continue }`。`names` 已经过滤空串，因此剩余的前缀匹配语义不变，不影响"DevEco-Studio" vs "DevEco Studio"这类归一化后互相包含的既有场景。

## 修复 2 — 成功判定回归规格

`app-control` 规格明确："成功判定不依赖窗口列表，仅以 `frontmostApplication` 为成功条件，`CGWindowListCopyWindowInfo` 只写诊断日志"。

`evaluationIfSettled` 当前对策略一（`activate(from:)`）和策略二（`openApplication`）传 `requireVisibleWindow: true`：

```swift
if requireVisibleWindow && !visible {
    visible = await waitForWindow(bundleID, timeout: 2.0)
}
guard !requireVisibleWindow || visible else { return nil }
```

进程内 `CGWindowList` 存在缓存偏差，窗口在其他桌面空间时 `可见窗口=0 离屏窗口=1` 是正常状态。应用已经 `frontmost=true` 却被判失败，继续走下一条策略并最终报"未能切前台，当前前台=目标应用"的自相矛盾结果。

修复：移除 `requireVisibleWindow` 参数及其分支，所有策略统一只看 `waitForFront`。`waitForWindow`/窗口计数保留用于诊断日志与"已运行但无可见窗口"的如实反馈。

## 修复 3 — 超时预算与手机端对齐

服务端最坏串行耗时：

| 策略 | 旧 | 新 |
|---|---|---|
| Dock 点击 | 8.0s | 2.0s |
| AXRaise | 5.0s | 1.5s |
| activate(from:) | 3.0s | 1.5s |
| openApplication | 3.0s | 1.5s |
| 合计 | 23s | 8.5s |

实际成功路径（Dock 命中）在 150ms 轮询内返回，不受这些上限影响。缩短上限只让"按错项"的失败路径更快收敛，不给正确路径增加任何延迟。

手机端 `PanelHTML.TIMEOUT.app` 从 20000 改为 12000 毫秒：高于服务端最坏 8.5s 加 HTTP 开销，低于旧的 20s，避免服务端还在跑时手机先显示超时。

## 验证

改动涉及 `AppControl.swift`，按 R3 属例外，需实际验证激活链路：
- `swift build -c release` 编译通过
- `./Build/build.sh` 构建 + 签名，签名校验通过
- 覆盖安装后从手机面板分别点 WorkBuddy 与其它受影响应用，确认秒回且切前台
- 检查 `activation.log`：不再出现空标题"已按下 Dock 图标"，不再出现"未能切前台，当前前台=目标应用"
