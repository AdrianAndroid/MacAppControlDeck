# pairing-auth 规格增量

## ADDED Requirements

### Requirement: 一次性配对码

系统 SHALL 在 Mac 端按需生成 6 位一次性配对码，具有短时效、防爆破与用后即焚特性。

#### Scenario: 生成并展示配对码

- **WHEN** 用户在 Mac 端点击"生成配对码"
- **THEN** 生成 6 位随机码并在 Mac 端 UI 显示，有效期 2 分钟
- **AND** 过期、已被使用或被锁定后，旧码立即失效

#### Scenario: 防爆破

- **WHEN** 同一配对码被错误输入累计 3 次
- **THEN** 该配对码作废，需重新生成
- **AND** 服务端对配对接口做频率限制（如每设备每分钟最多 5 次尝试）

#### Scenario: 错误配对码不能获得访问权限

- **WHEN** 手机提交了错误或过期的配对码
- **THEN** 返回明确的配对失败响应，不签发任何 token
- **AND** Mac 端 UI 显示"有设备配对失败"的提示

### Requirement: 配对成功签发设备凭证

系统 SHALL 在配对码验证通过后，为该设备签发随机凭证并保存在本机设备表中。

#### Scenario: 首次配对成功

- **WHEN** 手机提交正确且未过期的配对码与设备名
- **THEN** 服务端生成 256-bit 随机 token 返回给手机
- **AND** token、设备名、配对时间写入本地 `devices.json`，文件权限设为仅当前用户可读写

#### Scenario: 凭证保存位置

- **WHEN** 凭证在两端保存
- **THEN** Mac 端保存在本机 JSON 设备表，手机端保存在浏览器 localStorage
- **AND** 凭证不写入 URL 查询参数、二维码内容或访问日志

### Requirement: 所有业务端点要求凭证

系统 SHALL 对除健康检查与配对端点以外的所有 HTTP 端点要求有效设备凭证，未携带或校验失败一律拒绝。

#### Scenario: 未配对设备不能控制 Mac

- **WHEN** 没有携带 token 的请求调用按钮列表或激活命令端点
- **THEN** 返回 401，不执行任何动作
- **AND** 返回体指示"需要配对"，前端据此引导用户进入配对流程

#### Scenario: 已撤销设备的旧凭证失效

- **WHEN** 用户在 Mac 端撤销了某设备的配对，该设备随后用旧 token 请求
- **THEN** 返回 401 并指示"已撤销"，旧设备无法执行任何操作
- **AND** 设备表中该 token 记录被立即删除

### Requirement: 防跨站与 DNS 重绑定

系统 SHALL 通过凭证自定义头、Host 校验与 Origin 校验三重手段阻止浏览器跨站请求与 DNS 重绑定攻击。

#### Scenario: 跨站请求被拒

- **WHEN** 其他网页尝试跨站调用本服务端点
- **THEN** 携带自定义 token 头的请求会先触发 CORS 预检，服务端一律拒绝预检
- **AND** 不携带自定义头即被 401 拒绝，跨站方读不到响应内容

#### Scenario: Host 头校验

- **WHEN** 请求的 Host 头不是本机 IP 或 localhost
- **THEN** 请求被拒绝（如 DNS 重绑定攻击场景），返回 403

### Requirement: 请求范围白名单

系统 SHALL 只接受白名单动作：列出按钮、激活某个已配置按钮、配对、健康检查；不提供执行 shell 或任意 App 调用的能力。

#### Scenario: 请求未配置的应用

- **WHEN** 激活请求携带的按钮 ID 不存在于按钮配置中
- **THEN** 返回明确的"按钮不存在"错误，不启动任何应用

#### Scenario: 请求体限制

- **WHEN** 请求体超过大小上限（4KB）或 Content-Type 不是 application/json
- **THEN** 请求被拒绝并返回明确错误码

### Requirement: 管理已配对设备

用户 SHALL 能在 Mac 端查看已配对设备列表（设备名、配对时间）并撤销任意设备的配对。

#### Scenario: 撤销设备

- **WHEN** 用户在 Mac 端点击某设备的"撤销配对"并确认
- **THEN** 该设备 token 立即从设备表删除，其后续请求全部 401
