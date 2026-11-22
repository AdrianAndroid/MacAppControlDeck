# pet-live2d-bongocat 规格 delta

## MODIFIED Requirements

### Requirement: 单一桌面来源

桌宠场景 SHALL 只由一张 `background.clean.png` 提供鼠标垫、键盘和桌面轮廓；背景 SHALL 是透明 PNG，不得保留官方白桌、桌线或独立投影。场景画布 SHALL 保持 612×354，由 `background.clean.png` 满幅覆盖。

#### Scenario: 无白桌悬浮

- **WHEN** 桌宠在任意壁纸上显示
- **THEN** 画面只有完整圆角鼠标垫、完整键盘和动态猫
- **AND** 不出现白色桌面、第二根桌线或键鼠被画布裁断的边

### Requirement: 键位高亮置顶

键位高亮图层 SHALL 绘制在背景和模型之上，真实输入引起的高亮不得被模型、桌面或背景遮挡。该图层沿用官方 612×354 键位坐标；当背景键盘被替换为不同透视的完整键盘时，允许高亮与键帽位置暂时不完全对齐，但该限制 SHALL 在发布说明中列为已知问题，直到逐键重映射完成。

#### Scenario: 按住 A

- **WHEN** 用户按下物理 A 键
- **THEN** 键位高亮显示在最上层，松开后正常回落
- **AND** 若高亮坐标尚未按新键盘重映射，发布说明必须披露该偏差

### Requirement: 素材发布边界

BongoCat standard 模型与键位素材的来源和许可证 SHALL 在公开发布前核实并记录；确认上游为 Apache-2.0 后，方可进入公开发布包。发布包 SHALL 随附上游许可证原文与本项目修改说明。

#### Scenario: 准备公开发布

- **WHEN** 应用准备对外分发
- **THEN** `THIRD_PARTY_NOTICES.md` 记录上游地址、固定提交、许可证和改动范围
- **AND** 安装包内包含 `Licenses/BongoCat-LICENSE.txt`
