# global-hotkeys 变更（default-disable-global-hotkeys）

## ADDED Requirements

### Requirement: 默认关闭与旧配置迁移

全局快捷键 SHALL 在首次安装与恢复默认后全部处于关闭状态，不注册任何系统级快捷键。

#### Scenario: 首次安装

- **WHEN** 没有 `hotkeys.json`
- **THEN** 总开关为开，但所有快捷键默认关闭
- **AND** 不注册任何 Carbon 热键，F1、⌘⇧X、⌃⌥D、⌃⌥P 都不再抢占按键

#### Scenario: 旧配置迁移

- **WHEN** 读取到上一版生成、没有 `shortcutsOffByDefault` 标记的 `hotkeys.json`
- **THEN** 保留各入口已保存的组合与总开关
- **AND** 把所有入口改为关闭并写回标记
- **AND** 迁移只执行一次，之后尊重用户的开关选择

#### Scenario: 单项重置

- **WHEN** 用户在录制弹窗点「恢复默认组合」
- **THEN** 只把组合还原为默认
- **AND** 不改变该入口的开关状态

## MODIFIED Requirements

### Requirement: 修改与重置组合

设置页 SHALL 允许录制新的组合，并支持单项或全部恢复默认。

#### Scenario: 录制新组合

- **WHEN** 用户在「修改」弹窗里按下新组合
- **THEN** 弹窗预览新组合，保存后立即按新组合注册
- **AND** 旧组合不再生效

#### Scenario: 录制时暂停

- **WHEN** 修改弹窗打开
- **THEN** 所有全局快捷键临时注销，避免吞掉要录制的按键
- **AND** 关闭弹窗后自动恢复

#### Scenario: 缺修饰键

- **WHEN** 用户录制单个字母或数字
- **THEN** 提示至少需要一个修饰键，不保存
- **AND** F1–F12 允许无修饰键

#### Scenario: 恢复默认

- **WHEN** 用户点「全部恢复默认」
- **THEN** 所有组合恢复为内置默认
- **AND** 所有快捷键变为关闭状态
- **AND** 总开关状态不被强行修改
