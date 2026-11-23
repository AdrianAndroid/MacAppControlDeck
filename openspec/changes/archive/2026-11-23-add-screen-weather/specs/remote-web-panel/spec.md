# remote-web-panel 变更（add-screen-weather）

## ADDED Requirements

### Requirement: 副屏天气展示

副屏 SHALL 在同一页面展示实时天气与未来 3 天预报；天气数据由 Mac 端代理获取，页面不接触凭据与坐标。

#### Scenario: 横屏 L2 布局

- **WHEN** 副屏在横屏加载且天气可用
- **THEN** 左侧为时钟，右侧自上而下为「实时天气 / 月历 / 3 天预报」
- **AND** 时钟保持大尺寸，页面不出现滚动

#### Scenario: 竖屏布局

- **WHEN** 副屏在竖屏或窄屏加载
- **THEN** 自上而下为「时钟 / 实时天气 / 月历 / 3 天预报」
- **AND** 字号随视口收窄，320 宽下仍不溢出

#### Scenario: 实时天气内容

- **WHEN** `/api/weather` 返回 `ok: true`
- **THEN** 显示温度、天气现象、今日最高/最低、降水概率
- **AND** 显示更新时间和「和风天气」署名
- **AND** 天气图标为单色，不改变月份与今天所用的红色强调

#### Scenario: 3 天预报

- **WHEN** 返回 `daily` 至少 1 项
- **THEN** 横向等分展示最多 3 天，每项包含星期/图标/最高最低温

#### Scenario: 未配置天气

- **WHEN** 用户未填写和风凭据或未选择城市
- **THEN** 页面不显示天气块，时钟与月历按原布局填满
- **AND** `/api/weather` 返回 `reason: "not-configured"`

#### Scenario: 数据过期或失败

- **WHEN** 上游请求失败但存在缓存
- **THEN** 继续显示缓存数据并标记「已过期」
- **WHEN** 失败且无缓存
- **THEN** 天气区显示「天气暂不可用」，时钟与月历不受影响

### Requirement: 天气凭据与设置

Mac 端 SHALL 提供副屏天气设置：和风 API Host、JWT 凭据、城市搜索与连接测试；私钥只保存在钥匙串。

#### Scenario: 生成密钥与公钥

- **WHEN** 用户点击「生成密钥对」
- **THEN** 应用生成 Ed25519 密钥对，私钥写入钥匙串，界面展示可复制的公钥 PEM
- **AND** 重新生成时提示旧公钥将失效

#### Scenario: 城市搜索

- **WHEN** 凭据完整且用户搜索城市
- **THEN** 应用调用和风 GeoAPI，展示候选城市供选择
- **AND** 保存城市名称与经纬度，天气请求使用两位小数坐标

#### Scenario: 测试连接

- **WHEN** 用户点击「测试连接」
- **THEN** 应用用当前凭据请求实时与 3 天数据并显示结果
- **AND** 失败时展示可读原因，不记录或展示 JWT/私钥

#### Scenario: 凭据隔离

- **WHEN** 手机打开 `/api/weather`
- **THEN** 响应只包含城市名与天气数据，不包含 API Host、kid/iss/sub、坐标、JWT 或私钥
