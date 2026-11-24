# Tasks: MEM 菜单栏内存占用下拉菜单

- [x] 1. 在 `ProcessResourceMonitor` 增加一次性内存采样 API（`sampleMemoryTop(limit:)`），点击时 `await` 取前 N 个按内存降序的 `ProcessResourceConsumer`。
- [x] 2. 把进程页的 `canTerminate` 安全规则提取为共享工具 `ProcessTerminationPolicy`（`/Applications` 或用户主目录），菜单与进程页共用。
- [x] 3. 新建 MEM 菜单构建组件 `MemoryMenuBuilder.swift`（`NSMenu` + 自定义进程行视图：图标 / 名称 / 占用大小 / 关闭按钮 + 标题与底部提示）。
- [x] 4. `SystemToolModule`：MEM 状态项点击改为弹出该菜单；CPU / 网速点击行为不变。
- [x] 5. 格式化占用大小（B/KB/MB/GB）并加单元测试。
- [x] 6. `swift build` + 全量测试通过（166 项，4 skip）；release 覆盖安装，截图验收菜单形态。
- [x] 7. 更新调研文档与工作日志。
