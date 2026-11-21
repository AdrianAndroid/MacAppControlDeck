# 任务清单：add-chinese-calendar

## 1. 变更与依赖

- [x] 1.1 建立 OpenSpec 变更与 `calendar-window` 能力 delta
- [x] 1.2 在 `Package.swift` 接入 `6tail/lunar-swift`
- [x] 1.3 更新 `THIRD_PARTY_NOTICES.md` 的 LunarSwift MIT 说明

## 2. 数据与生命周期

- [x] 2.1 新增 `CalendarPreferences`，默认非常驻、周一开头
- [x] 2.2 新增 `CalendarDay` 与 `CalendarStore`，生成 42 天月历数据
- [x] 2.3 新增 `CalendarModule` 轻量代理与 `CalendarRuntime`
- [x] 2.4 窗口关闭后按 `resident` 决定是否释放 runtime
- [x] 2.5 设置页增加常驻内存开关与周起始日

## 3. 界面与入口

- [x] 3.1 新增 720×800 日历窗口、7 列月历、日期详情与倒计时
- [x] 3.2 菜单增加「万年历」子菜单与「打开万年历…」
- [x] 3.3 注册 `calendar.open` 内置操作
- [x] 3.4 默认快捷按钮播种「万年历」
- [x] 3.5 在 `DeckApp` 注册模块，设置页增加「万年历」tab

## 4. 验证

- [x] 4.1 新增 `CalendarStoreTests`，校验 2026-11-21 农历、42 格与倒计时
- [x] 4.2 `swift test` 全量通过
- [x] 4.3 `./Build/build.sh` 构建、签名成功
- [x] 4.4 启动应用，菜单打开日历窗口，关闭后 runtime 释放
- [x] 4.5 检查常驻开关：开启保留、关闭释放

## 5. 文档与归档

- [x] 5.1 README 增加万年历章节与入口说明
- [x] 5.2 新增 `Docs/archive/2026-11-21-chinese-calendar/SUMMARY.md`
- [x] 5.3 归档 OpenSpec 变更并同步 `openspec/specs/calendar-window/spec.md`
- [x] 5.4 提交说明引用 `add-chinese-calendar`
