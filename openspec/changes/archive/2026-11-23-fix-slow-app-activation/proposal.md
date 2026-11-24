# 提案：修复手机打开应用普遍响应慢

## Why

用户反馈手机面板点开 WorkBuddy 很慢，点豆包却很快。排查 `activation.log` 发现这是系统性问题：全日志 114 次 Dock 按下中 52 次是空标题（按错项），20 次"未能切前台"里有 12 次当前前台其实已经是目标应用本身。

根因有三：
1. `pressDockIcon` 的名称匹配用 `$0.hasPrefix(normalized)`，当 Dock 项标题归一化后为空串时该判断恒为 true，任意应用都能"匹配"到 Dock 分隔符/空标题项并按下，按完毫无效果，函数却返回 true，进入 8 秒空等。
2. `evaluationIfSettled` 对策略一/二加了 `requireVisibleWindow: true`，与 `app-control` 规格"成功判定不依赖窗口列表"冲突，应用已成前台却因可见窗口数为 0 被判失败，继续跑后续策略。
3. 串行 fallback 最坏耗时 8+5+(3+2)+(3+2)=23 秒，超过手机端 20 秒超时，手机先显示"已超时，放弃"，体感是点了没反应。

## What Changes

- `pressDockIcon`：跳过归一化后为空的 Dock 项标题，堵住空串 prefix 恒真的误匹配。
- `evaluationIfSettled`：移除 `requireVisibleWindow` 门槛及窗口等待，回归规格——成功只看 `frontmostApplication`。
- 缩短各级 fallback 超时：Dock 点击 8→2 秒、AXRaise 5→1.5 秒、上下文激活/LSOpen 3→1.5 秒。
- 手机面板 app 请求超时 20→12 秒，与服务端最坏耗时对齐。

## Capabilities

### Modified Capabilities

- `app-control`：激活成功判定与 Dock 图标匹配。
- `remote-web-panel`：手机端 app 按钮请求超时。

## Impact

- 代码：`Control/AppControl.swift`、`Panel/PanelHTML.swift`。
- 用户可见：绝大多数应用从 15~20 秒（或手机超时）降到 1 秒内切到前台，不再误报"未能切前台"。
- 不改变：Bundle ID、签名身份、TCC 授权、按钮配置结构、跨桌面切换的系统开关依赖。

## 非目标

- 不重构激活策略的整体分层，不新增策略。
- 不改变成功提示文案与跨桌面空间的系统行为。
- 不修改已保存的 `buttons.json`。
