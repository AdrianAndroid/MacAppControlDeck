# 任务：修复手机打开应用普遍响应慢

- [x] 1.1 `pressDockIcon` 跳过归一化后为空的 Dock 项标题
- [x] 1.2 `evaluationIfSettled` 移除 `requireVisibleWindow` 门槛，成功只看前台
- [x] 1.3 缩短 Dock 点击/AXRaise/上下文激活/LSOpen 的等待上限
- [x] 1.4 手机面板 app 请求超时 20s → 12s，面板版本 7 → 8
- [x] 1.5 `swift build -c release` 编译通过
- [x] 1.6 `./Build/build.sh` 构建 + 签名，覆盖安装 + 签名校验通过
- [x] 1.7 实际验证激活链路（R3 例外）：E2E 激活用例通过；模拟手机点击 WorkBuddy/Orca/豆包均在 350ms 内返回 activated；日志显示 Dock 图标标题正确、前台立即成功，无空标题与误判
- [x] 1.8 同步规格并归档

## 已知既有问题（非本次引入）
- `APIRouterTests.test_panelServedWithoutToken` 断言 `writing-mode:vertical-rl`，但 PanelHTML 该样式早已移除，测试与实现不同步，属既有失败。
- EndToEndActivationTests `test_unknownButtonNeverLaunchesAnything` 受前序用例启动的 Calculator 进程污染而失败，属测试用例隔离问题。
- AGENTS.md R2 记录的证书指纹 `145aea72...` 与本机实际 `e8357462...` 不一致，未改动（不影响本次修复，建议单独变更同步）。
