# 任务：手机面板横屏增加系统时钟

## 1. 实现

- [x] 1.1 标题栏新增 `#clock` 元素，默认隐藏
- [x] 1.2 横屏媒体查询下显示时钟，竖屏保持隐藏
- [x] 1.3 JS 每秒刷新：`YYYY年MM月DD日 星期X HH:mm:ss`，等宽数字
- [x] 1.4 提升 `PanelHTML.version` 触发已打开面板自动刷新

## 2. 验证

- [x] 2.1 本地 mock 面板在 844×390 横屏下显示时钟并每秒走动
- [x] 2.2 390×844 竖屏下不显示时钟，标题栏不换行、不溢出
- [x] 2.3 `swift build -c release` 通过
- [x] 2.4 `./Build/build.sh` + `./Build/verify-signing.sh` 签名仍稳定
- [x] 2.5 真机 iPhone 横竖屏旋转确认显示切换正确
