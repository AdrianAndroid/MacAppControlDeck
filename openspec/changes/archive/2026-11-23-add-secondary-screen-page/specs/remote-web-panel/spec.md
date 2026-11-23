# remote-web-panel 变更（add-secondary-screen-page）

## ADDED Requirements

### Requirement: 只读副屏页面

局域网服务 SHALL 在 `/screen/` 提供独立的只读页面：显示手机本地时间的模拟时钟与当月月历，页面不包含配对凭证、不调用任何 `/api/*` 接口、不展示或触发任何按钮。

#### Scenario: 免配对访问

- **WHEN** 未配对的手机或平板打开 `http://<Mac IP>:<端口>/screen/`
- **THEN** 页面直接显示模拟时钟与月历
- **AND** 不出现配对页、不读取 `deck_token`、不请求 `/api/*`

#### Scenario: 入口跳转与缓存

- **WHEN** 请求 `/screen`、`/screen/` 或 `/screen/index.html`
- **THEN** 服务 302 跳转到 `/screen/?v=<副屏版本>`
- **AND** 页面响应包含 `Cache-Control: no-store, must-revalidate`

#### Scenario: 横屏布局

- **WHEN** 副屏页面在横屏下加载
- **THEN** 时钟在左、月历在右，两者填满可用高度
- **AND** 页面不出现纵向或横向滚动

#### Scenario: 竖屏布局

- **WHEN** 副屏页面在竖屏下加载
- **THEN** 时钟在上、月历在下，月历保持完整 6 行网格
- **AND** 旋转屏幕后按新方向重新布局

#### Scenario: 时钟与月历内容

- **WHEN** 页面运行中
- **THEN** 时钟按手机本地时间绘制 60 格刻度、1–12 数字与时针/分针/秒针
- **AND** 月历显示当月全部日期，今天用红色圆形标记，红色月份名与 S–S 星期表头
- **AND** 秒针与月历在跨分钟、跨日期后自动更新

#### Scenario: 三档尺寸

- **WHEN** 用户在控制条切换「小 / 中 / 大」
- **THEN** 字号、间距与圆角按对应比例立即缩放
- **AND** 选择写入 `localStorage`，刷新后保持

#### Scenario: 保持常亮与全屏

- **WHEN** 浏览器支持 Wake Lock
- **THEN** 页面申请屏幕常亮，并在回到前台时重新申请
- **AND** 不支持时常亮状态显示为不可用，不谎报已开启
- **AND** 支持全屏的浏览器显示全屏按钮，iOS Safari 不显示

#### Scenario: 月份浏览

- **WHEN** 用户点击 ‹ 或 ›
- **THEN** 月历切换到上/下个月，今天标记只在对应月份出现
- **AND** 点击月份名立即回到当月
- **AND** 浏览他月超过 60 秒无操作后自动回到当月

### Requirement: 副屏地址入口

Mac 端 SHALL 在菜单栏、设置页和内置操作中提供副屏地址入口。

#### Scenario: 菜单栏

- **WHEN** 用户打开菜单栏「电脑控制」
- **THEN** 可见「副屏：<IP>:<端口>/screen/」、「在浏览器打开副屏」与「复制副屏地址」

#### Scenario: 设置页

- **WHEN** 用户打开设置 → 服务
- **THEN** 副屏卡片显示完整地址，并提供复制与打开按钮
- **AND** 文案说明副屏只读、免配对、不影响设备配对

#### Scenario: 内置操作

- **WHEN** 用户从「按钮管理 → 添加内置操作」添加「打开副屏」
- **THEN** 该按钮出现在菜单栏快捷操作与手机面板快捷操作区
- **AND** 点击后在 Mac 浏览器打开副屏地址
