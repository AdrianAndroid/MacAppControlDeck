# 提案：手机副屏页面（模拟时钟 + 月历）

## Why

家里闲置的手机/平板可以一直亮着当桌面副屏，但现有 `/panel/` 是操作面板：需要配对、显示按钮、只适合拿在手里点。把一台旧手机当表盘/日历用时，用户既不想让它占用配对设备，也不希望页面上出现可执行按钮。

一个独立的只读页面最合适：另一台手机打开不同地址，就得到一个全屏的模拟时钟 + 当月月历，和控制面板互不影响。

## What Changes

- 新增只读页面路由 `/screen/`：
  - 左侧（横屏）/ 上方（竖屏）为模拟时钟：60 格刻度、1–12 数字、白色时针/分针、橙色秒针、金色轴心
  - 右侧（横屏）/ 下方（竖屏）为当月月历：红色月份名、S–S 星期表头、红色圆形标记今天
  - 纯深色外观，红色强调色，贴合参考图
- 页面为**纯前端只读**：不发任何 `/api/*` 请求、不读取也不携带配对 token、不显示按钮；日期时间全部由手机本地计算。
- 三档尺寸（小/中/大），选择写入 `localStorage`；点按屏幕唤出控制条（尺寸、全屏、常亮状态），5 秒后自动隐藏。
- 支持 Wake Lock 保持屏幕常亮；`visibilitychange` 后自动重新申请；不支持的浏览器静默降级。
- 月份可前后浏览，点击月份名回到当月；60 秒无操作自动回到当月。
- 版本与缓存：`/screen`、`/screen/`、`/screen/index.html` 302 跳转到 `/screen/?v=<版本>`，响应 `Cache-Control: no-store`。
- Mac 端入口：
  - 菜单栏「电脑控制」新增「在浏览器打开副屏」与「复制副屏地址」
  - 设置 → 服务 新增副屏地址卡片（复制 / 打开）
  - 内置操作新增 `screen.open`「打开副屏」，可从按钮管理添加，并出现在菜单栏快捷操作与手机面板快捷操作区

**非目标**：

- 不做 Mac 本机悬浮副屏窗口（本次只做手机网页）。
- 不在副屏上显示农历、节气、节假日、系统状态或媒体信息。
- 不允许从副屏触发任何控制动作；副屏不能替代 `/panel/`。
- 不做公网访问、HTTPS 或账号体系。

## Capabilities

### New Capabilities

- 无。

### Modified Capabilities

- `remote-web-panel`：新增免配对只读副屏页面，以及 Mac 端副屏地址入口。

## Impact

- 代码：新增 `Sources/MacAppControlDeck/Panel/ScreenHTML.swift`；修改 `Server/APIRouter.swift`、`Server/LANAddress.swift`、`App/DeckState.swift`、`Modules/RemoteControl/RemoteControlModule.swift`、`Control/BuiltinActions.swift`、`UI/SettingsView.swift`。
- 测试：`Tests/MacAppControlDeckTests/APIRouterTests.swift` 增加副屏路由用例。
- 数据与权限：无新增权限；不写入任何新配置；页面不接触配对数据。
- 安全边界：副屏页面只包含静态 HTML/CSS/JS，同网段设备拿到地址也只能看到时间与日历。
