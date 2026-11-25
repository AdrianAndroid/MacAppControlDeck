# Tasks

- [x] 设计、提案与能力 delta
- [x] 实现
- [x] `swift build` / `./Build/build.sh` 通过（macOS 27 SDK 需动态解析被移除的 CG API）
- [x] 固定签名覆盖安装
- [x] 截图验收（`Docs/verification/screen-countdown/frames-*.png`；状态栏见菜单栏截图）
- [x] 同步 `openspec/specs` 并归档

## Verification

- 菜单栏实测：主图标独立保留（带 `autosaveName`，⌘-拖动后位置持久），CPU / MEM / 网速合成一条状态项、组内顺序固定
- 组内命中修复：内容视图改为不参与 hitTest，点击落到各自格子（修复「点哪个都弹同一个」）
- 设置 → 状态栏：模块关闭时开关置灰、勾选保留、状态栏对应格消失
- 主图标与监控组位置仍由 macOS 布局决定，程序不对其排序；提供 ⌘-拖动一次性摆位
