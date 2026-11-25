# 副屏设置统一到 Mac 端

副屏控制条此前包含尺寸切换、桌宠设置、常亮状态等多个设置入口，手机端即可改动配置。本次改造把这三档尺寸、桌宠模式/宠物/随机间隔、「立即换一只」以及屏幕常亮开关全部收拢到 Mac 端「设置 → 副屏」中；副屏控制条只保留「强制刷新」与浏览器支持时的「全屏」。

## Why

- 副屏是只读展示页，手机端不应成为配置入口；统一在 Mac 端设置更符合“副屏只读”的定位。
- 配置散落在手机 `localStorage` 中，Mac 端无法感知或批量管理，排障困难。
- 控制条按钮过多，遮挡内容。

## What Changes

- 新增 `ScreenDisplaySettings`：尺寸、桌宠模式、宠物、随机间隔、常亮、换宠计数，持久化到 Mac `UserDefaults`，变更时推送屏幕刷新事件。
- 新增只读 `GET /api/screen/display`，由 Mac 下发给所有副屏页面。
- 副屏删除尺寸按钮、桌宠设置面板、常亮状态文字，以及所有 `localStorage` 读写；改为启动/刷新/事件/回到前台时拉取 Mac 配置。
- Mac 端「设置 → 副屏」新增「副屏显示与桌宠」卡片，可配置全部选项。
- 副屏 HTML 从 Swift 源码抽到 Bundle 资源文件，后续改页面不再触发整个 Swift module 全量重编译。

## Capabilities

### New Capabilities

- `screen-display-settings`：Mac 端统一维护并下发副屏显示与桌宠配置。

### Modified Capabilities

- `remote-web-panel`：副屏控制条只保留刷新与全屏；尺寸/桌宠/常亮改为 Mac 端配置。
