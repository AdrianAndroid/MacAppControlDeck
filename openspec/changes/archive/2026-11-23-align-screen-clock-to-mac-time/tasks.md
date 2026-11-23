# 任务：副屏对齐 Mac 时间

## 1. 服务端

- [x] 1.1 `GET /api/time`：epoch、时区偏移、年月日时分秒、ISO，`no-store`
- [x] 1.2 路由测试：字段范围、时间接近当前、不含敏感信息

## 2. 页面

- [x] 2.1 建立 `macWall()` 墙钟（epoch + offset + 已过时间，UTC getter）
- [x] 2.2 时钟改用墙钟绘制
- [x] 2.3 月历当前月、今天高亮、月份自动回当月改用墙钟
- [x] 2.4 3 天预报的「今天/明天/后天/周几」改用墙钟日期
- [x] 2.5 启动/每 10 分钟/回到前台同步；失败回退手机本地时间
- [x] 2.6 同步不打断用户正在浏览的他月
- [x] 2.7 页面版本提升到 `2026-11-23.3`

## 3. 验证

- [x] 3.1 用 mock `/api/time` 指向不同日期，确认月历与时钟采用 Mac 日期
- [x] 3.2 无头截图横竖屏无溢出
- [x] 3.3 构建、覆盖安装、签名校验
- [x] 3.4 真实 Mac 页面与系统日期一致

## 4. 归档

- [x] 4.1 同步 `openspec/specs/remote-web-panel/spec.md`
- [x] 4.2 更新 README
- [x] 4.3 归档到 `openspec/changes/archive/2026-11-23-align-screen-clock-to-mac-time/`
