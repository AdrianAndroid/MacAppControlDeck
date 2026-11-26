# remote-web-panel Delta

## MODIFIED Requirements

### Requirement: 副屏只读与配置下发

副屏页面 SHALL 只读渲染，尺寸、宠物（当前支持 `cat / dog / robot / capybara`）、常亮等配置全部由 Mac 端 `/api/screen/display` 下发。

#### Scenario: 选择水豚

- **WHEN** 用户在 设置 → 副屏 → 桌宠 里选择「水豚」
- **THEN** 副屏宠物卡片切换为水豚（圆身 + 方鼻 + 头顶橘子）
- **AND** 状态道具（打伞 / Zzz / 围巾 / 表 / 星 / 汗滴）照常叠加在它身上

#### Scenario: 旧配置兼容

- **WHEN** 升级前保存的 `petId` 不是新值
- **THEN** 仍按原值渲染；非法值回退为 `cat`
