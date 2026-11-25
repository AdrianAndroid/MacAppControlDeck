# Tasks

- [x] `StatusBarRegistry` 渲染单位由 group 改为 entry（`StatusBarItemControl`，`isBuilt` 复用）
- [x] 每条状态项独立 `autosaveName`，点击改由按钮 action 直接转发，去掉分段命中
- [x] CPU 条目：`sampleCPUTop(limit:)`（基线 + 400ms 差分）+ 占用排行菜单
- [x] 网速条目：↑/↓ 速率菜单；MEM 沿用现有内存排行
- [x] 设置 →「状态栏」文案与 `StatusBarEntry.groupID` 注释改为「独立状态项」
- [x] 三条贴近：`variableLength` + 内容 0 内缩、不写死 `length`（写成固定 length 会给每项多留空白）
- [x] CPU / MEM 标签行改 `labelColor`，与数值行、网速项同色；百分比列按 `100%` 定宽防抖动
- [x] README 状态栏条目描述更新
- [x] 构建 + 固定签名覆盖安装
- [x] 真机点击验证：CPU / MEM / 网速三条各自弹出对应菜单（截图确认）
