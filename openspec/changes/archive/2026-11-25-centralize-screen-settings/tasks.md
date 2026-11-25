# 任务清单

- [x] 1. 新增 `ScreenDisplaySettings` / `ScreenDisplayConfig`，持久化并推送刷新事件。
- [x] 2. 新增只读 `GET /api/screen/display` 端点。
- [x] 3. Mac 端「设置 → 副屏」新增「副屏显示与桌宠」卡片。
- [x] 4. 副屏 HTML 删除尺寸按钮、桌宠设置面板、常亮状态与全部 localStorage 读写。
- [x] 5. 副屏改为从 Mac 拉取显示配置，支持刷新/事件/回到前台同步，保留强制刷新与全屏。
- [x] 6. 副屏 HTML 抽成 Bundle 资源文件，Swift 侧替换版本号占位符。
- [x] 7. 补测试：设置模型、换宠 nonce、API 端点、HTML 资源加载。
- [x] 8. 全量测试、release 构建、覆盖安装、离屏截图验收。
- [x] 9. 同步 `remote-web-panel` 主规格，归档 change。

## 验收结果

- 全量测试：175 项，4 skip，0 失败。
- 构建提速实测：只改 HTML 资源后 release 构建 4.00 秒（原 6.5 分钟）。
- DOM 检查：控制条只有 `refresh` 与 `fullscreen`，无 `.seg` / `petSettingsPanel` / `awake` / `localStorage`。
- 配置下发实测：Mac 改随机+小狗+30 秒+大尺寸后，副屏 `size=l`、30 秒后从像素猫换到机器人。
- 默认配置已恢复。
