# Tasks

- [x] 设计、提案与能力 delta
- [x] 实现
- [x] `swift build` / `./Build/build.sh` 通过（macOS 27 SDK 需动态解析被移除的 CG API）
- [x] 固定签名覆盖安装
- [x] 截图验收（`Docs/verification/screen-countdown/frames-*.png`；状态栏见菜单栏截图）
- [x] 同步 `openspec/specs` 并归档

## Verification

- `swift build` / `./Build/build.sh` 通过（macOS 27 SDK 下需动态解析被移除的 CG API）
- 四视口实测：844×390 / 480×320 / 1440×900 / 500×900，`data-frames=on`、强度 0.16，`wxClip=false`、无页面滚动
- 截图：`Docs/verification/screen-countdown/frames-*.png`
- 加框后天气列会少约 20px，已收紧内部行距（小时条 / 预报 / 更新行）避免压出框外
