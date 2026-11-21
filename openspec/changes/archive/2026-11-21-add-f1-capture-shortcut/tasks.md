# 任务清单：add-f1-capture-shortcut

## 1. 实现

- [x] 1.1 在 `GlobalHotKeys` 注册 F1（keyCode `kVK_F1`、无修饰键、id 9）
- [x] 1.2 F1 通过 `CaptureModule.shared.captureArea()` 触发，确保同步截图偏好
- [x] 1.3 保留 `⌘⇧X`，确认两个快捷键不会叠加覆盖层
- [x] 1.4 在截图设置页增加 F1 提示

## 2. 文档

- [x] 2.1 README 截图章节补充 F1 与 `⌘⇧X`
- [x] 2.2 README 已知限制补充 F1 与手机端 F1 按钮的冲突
- [x] 2.3 `Docs/architecture/MACSHOT_PORT.md` 全局快捷键清单加入 F1

## 3. 验证

- [x] 3.1 补充全局热键配置测试并通过
- [x] 3.2 `swift test` 全量通过
- [x] 3.3 `./Build/build.sh` 构建并签名成功
- [x] 3.4 启动应用，确认 F1 能打开区域截图、`⌘⇧X` 仍可用

## 4. 归档

- [x] 4.1 `openspec/specs/capture-overlay-parity/spec.md` 同步 F1 要求
- [x] 4.2 变更归档到 `openspec/changes/archive/YYYY-MM-DD-add-f1-capture-shortcut/`
- [x] 4.3 README / Docs 归档索引加入本次需求
- [x] 4.4 提交并推送 `main`，提交说明引用 `add-f1-capture-shortcut`
