# project-documentation 变更（add-puremac-ui-redesign-and-lemon-research）

## ADDED Requirements

### Requirement: 竞品调研文档可复现

竞品或桌面 App 的调研文档 SHALL 记录环境、证据、操作路径、已知限制与未完成清单，使他人能在另一台机器上复现同一调研。

#### Scenario: 调研文档结构

- **WHEN** 新增一份调研文档
- **THEN** 文档包含被测 App 版本与 Bundle ID、运行环境、调研日期
- **AND** 包含功能地图（入口、页签、设置项）
- **AND** 列出每张截图的文件名、对应界面与采集状态
- **AND** 列出未完成项与下一步操作

#### Scenario: 证据可追溯

- **WHEN** 文档引用截图
- **THEN** 截图保存在仓库内固定目录，文件名为「序号-界面名.png」
- **AND** 文档中的路径与实际文件一致
- **AND** 截图必须来自真机运行，不得用示意图冒充

#### Scenario: 结论不越界

- **WHEN** 文档描述尚未验证的功能
- **THEN** 明确标注「未采集 / 待确认」
- **AND** 不得把未观察到的行为写成已确认结论

### Requirement: UI 设计方案可执行

UI 设计文档 SHALL 包含可直接落地的布局图、组件规格与逐文件改动映射，避免只有原则没有实现路径。

#### Scenario: 设计文档交付

- **WHEN** 提交一份 UI 重做方案
- **THEN** 包含整窗骨架、统一页面骨架、每个页面的布局图与三态图
- **AND** 包含间距、行高、字号、圆角与语义色 token
- **AND** 映射到具体源文件与代码位置
- **AND** 标注参考来源与刻意不采用的设计
