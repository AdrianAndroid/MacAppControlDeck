# 任务：状态栏增加「区域截图」快捷图标

## 1. 条目

- [x] 1.1 新增 `CaptureStatusBarEntry`：`capture.region`、`rectangle.dashed`、`order = 4`、默认显示
- [x] 1.2 点击直接调用 `MacShotController.captureArea()`，不弹菜单
- [x] 1.3 `CaptureModule.start()` 注册条目，避免重复注册
- [x] 1.4 模块关闭时由公共状态栏层自动移除，重新启用后恢复

## 2. 设置与文档

- [x] 2.1 设置 → 状态栏 出现「截图与录屏 / 区域截图」开关
- [x] 2.2 README 截图段落与归档记录补充入口
- [x] 2.3 能力规格 `status-bar` 增加该条目

## 3. 验证

- [x] 3.1 `swift build` 通过
- [x] 3.2 `swift test --filter CaptureStatusBarEntryTests` 2 项通过
- [x] 3.3 覆盖安装后真机点图标确认进入区域截图
