# project-documentation 规格

## ADDED Requirements

### Requirement: README 主功能界面截图

README SHALL 为所有主要用户可见模块提供真实界面截图，至少覆盖菜单栏、设置页、截图/录屏、UI 草图与手机面板；截图 SHALL 放在使用路径对应章节，而不是只堆在文末。

#### Scenario: 新用户首次阅读

- **WHEN** 用户打开 README
- **THEN** 能在首屏看到菜单栏与手机面板的总览截图
- **AND** 在「Mac 端使用」「手机端使用」「截图、录屏与视频剪辑」「UI 草图」「设置界面」章节内看到对应界面截图
- **AND** 每张图配有说明其界面位置或用途的简短文案

#### Scenario: 模块缺少截图

- **WHEN** 新增或明显改动一个用户可见模块的主界面
- **THEN** 同一变更内补充或更新该模块的 README 截图
- **AND** 不允许用设计稿、示意图或假数据替代真实运行界面

#### Scenario: 运行态临时界面

- **WHEN** 某界面属于截图选区、录制 HUD、视频剪辑等运行态临时窗口，且截图会带入不可裁剪的隐私内容
- **THEN** 可以改用相邻的设置页、选区截图与使用步骤表达
- **AND** 必须在归档记录中写明未单独截图的范围，不能宣称“全部界面均已截图”

### Requirement: 截图真实性与隐私

README 截图 SHALL 来自真实运行的应用或真实接口数据；截图资产 SHALL NOT 包含设备 token、聊天记录、终端内容、通知或其他无关桌面窗口。

#### Scenario: 手机面板截图

- **WHEN** 生成手机端已配对面板截图
- **THEN** 面板使用真实配对 token 与真实按钮接口渲染
- **AND** 截图中不显示 token、配对码以外的凭证或真实设备隐私信息

#### Scenario: Mac 窗口截图

- **WHEN** 截取设置窗口或其他应用窗口
- **THEN** 优先只抓目标窗口，或在合成前裁掉桌面其他窗口
- **AND** 通知横幅、Finder 背景、聊天与终端内容不得进入最终资产

### Requirement: 截图资产目录与链接

截图 SHALL 统一存放在 `Docs/images/readme/`，使用语义化英文短横线命名，并通过仓库相对路径在 README 中引用。

#### Scenario: 图片引用有效

- **WHEN** README 在 GitHub 上渲染
- **THEN** 所有截图链接均为仓库相对路径且可访问
- **AND** 不出现本地绝对路径、`file://` 路径或依赖个人环境的路径

#### Scenario: 控制仓库体积

- **WHEN** 新增截图资产
- **THEN** PNG 经过优化，单图按展示尺寸压缩
- **AND** 长图在 README 中用 HTML `width` 限制展示尺寸，避免页面被撑得过高

### Requirement: 使用路径图文说明

每个主要模块 SHALL 在 README 中同时提供界面截图和可执行的使用步骤，覆盖入口、操作顺序与默认输出位置。

#### Scenario: 截图/录屏模块

- **WHEN** 用户阅读「截图、录屏与视频剪辑」
- **THEN** 能看到菜单子项、设置页与选区覆盖层截图
- **AND** 能按步骤完成截图、标注、钉图、录屏与视频导出
- **AND** 明确默认输出目录与可在设置中修改

#### Scenario: UI 草图模块

- **WHEN** 用户阅读「UI 草图」
- **THEN** 能看到画板与内置素材库截图
- **AND** 能按步骤新建画布、绘制、载入素材、复制图片/JSON、保存 PNG 与 `.excalidraw`

### Requirement: 需求归档可追溯

README 截图需求 SHALL 同时归档到项目文档目录与 OpenSpec 变更归档，并在 README 的「归档」索引中可发现。

#### Scenario: 查找归档

- **WHEN** 维护者从 README 的「归档」进入
- **THEN** 能找到 `Docs/archive/2026-11-21-readme-screenshots/SUMMARY.md`
- **AND** 能找到 `openspec/changes/archive/2026-11-21-add-readme-feature-screenshots/`
- **AND** 归档记录包含截图清单、实施方法、验证结果、提交与已知缺口
