# 提案：修正和风 v1 日预报字段解析

## Why

用真实和风 v1 响应校准后发现，日预报列表在 `days` 下，天气现象是 `daytime.condition.text/code`，最高低温是 `temperatureMax/Min.value`，降水概率是 `daytime.precipitation.probability`。旧解析只覆盖了猜测路径，导致 3 天预报显示「—」和默认云图标。

## What Changes

- 解析器优先读取真实 v1 路径：
  - `days[]`
  - `daytime.condition.text` / `daytime.condition.code`（夜间回退）
  - `temperatureMax/Min.value`
  - `daytime.precipitation.probability`
- 保留旧字段回退，兼容其他账号/版本。
- 实时天气图标支持 `condition.code`。
- 增加真实结构的 fixture 测试。

## Capabilities

### Modified Capabilities

- `remote-web-panel`：3 天预报字段解析。

## Impact

- 代码：`WeatherModels.swift`。
- 用户可见：3 天预报显示正确天气文字与单色图标，不再全是云。
