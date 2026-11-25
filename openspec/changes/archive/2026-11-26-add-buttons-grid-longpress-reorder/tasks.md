# 任务清单：add-buttons-grid-longpress-reorder

## 1. 结构与计算

- [x] 1.1 新增 `ButtonGridSupport.swift`：分组、卡片、`ButtonGridReorder`
- [x] 1.2 新增 `ButtonGridReorderTests`
- [x] 1.3 运行 `swift test --filter ButtonGridReorderTests`（7 项通过）

## 2. 界面

- [x] 2.1 `ButtonsSettingsView` 改为吸顶分组 + 4 列 `LazyVGrid`
- [x] 2.2 卡片显示应用图标/快捷符号/内置符号，名称两行，缺失应用橙色提示
- [x] 2.3 增加点击选中、底部操作条、搜索、分组折叠
- [x] 2.4 右键菜单保留重命名、编辑组合、上移、下移、删除
- [x] 2.5 吸顶分组标题改为不透明底色，滚动时不透视下方卡片

## 3. 手势

- [x] 3.1 按压状态机：按下选中、0.5s 准备、移动 >4pt 拖动
- [x] 3.2 拖动浮层、插入空隙、跨组红色不可放置提示
- [x] 3.3 拖动期间只维护本地预览，松手调用一次 `moveToIndex`
- [x] 3.4 搜索状态下禁用拖动排序

## 4. 验证与归档

- [x] 4.1 `swift build` 通过
- [x] 4.2 `./Build/build.sh` 与固定签名校验通过（CDHash `d4bb2f0c62358c1d00a77c34888ae38c9c5d1387`）
- [ ] 4.3 手工验证长按拖动全流程（未完成：gcu/Quartz 合成按住会被系统判定为用户接管并中断；点击选中、右键菜单、搜索过滤、分组折叠已实机确认，落位逻辑由 7 项单元测试覆盖）
- [x] 4.4 同步 `openspec/specs/button-panel-config/spec.md`
- [x] 4.5 归档变更并记录验证结果

## 验证记录

- `swift test --filter ButtonGridReorderTests`：7 项，0 失败。
- `./Build/build.sh`：编译、组装、Sparkle、固定签名通过。
- 实机确认：4 列网格、点击选中、底部操作条、右键菜单（重命名/上移/下移/删除）、搜索命中计数、分组折叠。
- 已知限制：第一版不做边缘自动滚动；长列表先滚到目标附近再拖动。
