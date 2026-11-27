# pairing-auth 变更（add-device-presence-and-pairing-qr）

## ADDED Requirements

### Requirement: 扫码配对与设备分类

系统 SHALL 保持主屏配对鉴权，同时提供一次性配对码二维码；「设备」页 SHALL 区分主屏与只读副屏。

#### Scenario: 主屏仍必须配对
- **WHEN** 设备要调用 `/api/buttons` 或 `/api/activate`
- **THEN** 必须持有 6 位一次性配对码换发的 token
- **AND** 副屏不持有 token，也不能执行任何操作

#### Scenario: 扫码配对
- **WHEN** 设置页展示配对码
- **THEN** 展示当前面板地址二维码，内容为 `panelURL?v=<version>&pair=<6位一次性码>`
- **AND** 二维码与 URL 不含长期 token
- **AND** 手机面板读取 `pair` 后自动调用配对接口，并立即从地址栏移除该参数

#### Scenario: 一次性
- **WHEN** 扫码使用的配对码过期或被使用
- **THEN** 与手动输入一样失败，不签发 token
- **AND** 错误 3 次仍会锁定作废

#### Scenario: 设备页分组
- **WHEN** 打开设置 → 设备
- **THEN** 「主屏 · 已配对（可操作）」只显示 token 设备，显示在线点/最近活动，可撤销
- **AND** 「副屏 · 只读（无需配对）」显示副屏浏览器登记，可清除记录
- **AND** 两组互不混淆，副屏记录不能获得操作权限
