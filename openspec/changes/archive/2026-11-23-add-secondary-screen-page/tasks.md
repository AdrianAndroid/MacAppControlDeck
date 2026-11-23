# 任务：手机副屏页面（模拟时钟 + 月历）

## 1. 页面与路由

- [x] 1.1 新增 `ScreenHTML.swift`：深色全屏布局、横竖屏自适应
- [x] 1.2 模拟时钟：60 刻度、1–12 数字、时针/分针/秒针、DPR 缩放、15fps 节流
- [x] 1.3 月历：红色月份名、星期表头、今天红色圆点、固定 6 行
- [x] 1.4 三档尺寸（小/中/大）与 `localStorage` 持久化
- [x] 1.5 Wake Lock 常亮、全屏按钮、控制条自动隐藏
- [x] 1.6 月份前后浏览 + 60 秒无操作回到当月
- [x] 1.7 `/screen`、`/screen/`、`/screen/index.html` 302 到带版本地址，响应 `no-store`

## 2. Mac 端入口

- [x] 2.1 `LANAddress.screenURL(port:)` 与 `DeckState` 副屏地址/复制/打开
- [x] 2.2 菜单栏「电脑控制」新增打开副屏与复制副屏地址
- [x] 2.3 设置 → 服务新增副屏地址卡片
- [x] 2.4 内置操作 `screen.open`「打开副屏」注册并接上实际动作

## 3. 验证

- [x] 3.1 路由测试：副屏免 token 可访问、入口带版本跳转、页面不含 token 与 `/api/`
- [x] 3.2 `swift build -c release` 与 `swift test` 通过（仅剩 2 个既有桌宠窗口尺寸断言，受本机屏幕影响）
- [x] 3.3 视口与交互验证：无头 Chrome 900×500 / 500×757 覆盖横竖屏与三档尺寸
- [x] 3.4 内置操作：预设注册单测通过；点击动作 `NSWorkspace.open(副屏地址)` 与菜单、设置页同一实现
- [x] 3.5 固定签名构建与 `verify-signing.sh` 校验通过
- [ ] 3.6 实体 iPhone Safari 走查（本机无可用设备；iOS 全屏按钮隐藏与 Wake Lock 行为按特性检测实现）

> 3.6 未完成的实体设备走查不影响归档：页面为纯前端只读实现，未在真机上留下未验证的权限或数据路径。

## 4. 归档

- [x] 4.1 同步 `openspec/specs/remote-web-panel/spec.md`
- [x] 4.2 更新 README 功能与归档链接
- [x] 4.3 变更归档到 `openspec/changes/archive/2026-11-23-add-secondary-screen-page/`
