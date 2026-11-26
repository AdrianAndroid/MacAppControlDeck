# remote-web-panel 变更（add-screen-pet-cat-chase-loop）

## ADDED Requirements

### Requirement: 宠物卡猫追老鼠

副屏宠物卡 SHALL 在待机时按设定间隔播放「鼠在前跑、猫在后追」的循环，
并在触到卡片边界时同时掉头。

#### Scenario: 待机时触发

- **WHEN** 宠物行为为 `idle`、宠物卡片可见、猫追老鼠开关为开，且距上次追逐已超过设定间隔
- **THEN** 卡片里出现鼠与猫，鼠在前、猫在后，同速同向移动

#### Scenario: 触边掉头

- **WHEN** 领跑的鼠前缘到达卡片左右边界（留 8px）
- **THEN** 两者同时掉头，位置镜像
- **AND** 鼠仍在猫前方，两只不重叠、不穿模

#### Scenario: 非待机状态

- **WHEN** 宠物进入睡觉 / 打伞 / 围巾 / 看表 / 庆祝等状态
- **THEN** 追逐立即结束，鼠消失，恢复该状态的常规表现

#### Scenario: 关闭开关

- **WHEN** 设置中关闭「猫追老鼠」，或隐藏宠物卡片
- **THEN** 不再触发追逐，只保留原有单只游走或整卡隐藏

#### Scenario: 图片来源

- **WHEN** 页面加载追逐素材
- **THEN** 使用内联帧条，不发起额外网络请求
- **AND** 猫为 CC0、鼠为 CC-BY 3.0，署名见 `THIRD_PARTY_NOTICES.md`

## MODIFIED Requirements

### Requirement: 副屏显示配置

`/api/screen/display` SHALL 额外下发 `petChase`（布尔）与 `petChaseInterval`（秒），
副屏据此决定是否播放追逐以及间隔。

#### Scenario: 配置生效

- **WHEN** Mac 端修改「猫追老鼠」或间隔
- **THEN** 副屏在一次轮询内应用新配置，无需刷新页面
