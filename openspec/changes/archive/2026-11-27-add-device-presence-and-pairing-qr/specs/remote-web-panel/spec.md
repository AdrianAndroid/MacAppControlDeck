# remote-web-panel 变更（add-device-presence-and-pairing-qr）

## ADDED Requirements

### Requirement: 副屏在线登记

副屏页面 SHALL 在不携带 token 的前提下登记自身，用于 Mac「设备」页展示。

#### Scenario: 打开与心跳
- **WHEN** 副屏页面加载
- **THEN** 生成并复用 localStorage 中的客户端 ID，向 `/api/screen/presence` 上报
- **AND** 页面可见时每 30 秒补报，回到前台立即补报

#### Scenario: 副屏二维码
- **WHEN** 打开 设置 → 副屏 或菜单「显示副屏二维码…」
- **THEN** 展示当前副屏地址二维码，扫码直接打开 `/screen/`
- **AND** 副屏免配对，打开后自动登记到「设备 → 副屏」

#### Scenario: 不接触敏感数据
- **WHEN** 上报登记
- **THEN** 只发送客户端 ID，不发送 token、按钮、天气凭据或用户输入
- **AND** 页面仍是只读，不因登记获得任何操作能力
