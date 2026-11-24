# Tasks

- [x] 建变更记录、设计与能力 delta
- [x] `SystemSampler.swift` 新增 getifaddrs 累计字节差分采样（活动接口聚合、跳 lo0、回绕归零），复用现有 2 秒定时器
- [x] 单位格式化：B/s → K/s → M/s 自动切档、1 位小数、0 值显示 0 K/s
- [x] 定宽格式 `formatSpeedFixed`（figure space U+2007 右对齐 + 等宽数字 9pt + 固定列宽），速率位数变化时宽度恒定、小数点对齐
- [x] 网速上下两行统一样式：↑/↓ 同为 9pt、同为 `.labelColor`，只靠箭头区分方向（弃用 ↑绿/↓蓝双字号）
- [x] `SystemToolModule.swift` 先合并、后按用户选择改为**三个独立 NSStatusItem**（反序创建保证 CPU|MEM|网速 顺序），各自可点击/单独开关
- [x] `SystemToolSettingsView.swift` 新增「实时网速」开关（showNetSpeed），三开关同源通知重建
- [x] 单元测试覆盖单位格式化、定宽格式与差分回绕（SystemToolTests 15 项）
- [x] 编译 + 全量测试通过 + release 构建签名 + 覆盖安装截图验收（读宽度恒定、上下同色同字号、数字完整）
- [x] 归档变更并同步 system-cleaner 主 spec
