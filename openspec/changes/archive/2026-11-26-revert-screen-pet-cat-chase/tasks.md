# 任务：回退副屏「猫追老鼠」

## 1. 移除

- [x] 1.1 删除 `--chase-cat` / `--chase-rat` 内联帧条
- [x] 1.2 删除 `.pet-chase` CSS、`chase-run` 关键帧与 `#petChase` DOM
- [x] 1.3 删除 `chase` 状态机与 `petStep` / `petSetBehavior` / `petApply` 里的追逐分支
- [x] 1.4 删除 `petChase` / `petChaseInterval` 配置、键与测试断言
- [x] 1.5 设置页移除「猫追老鼠」与「追逐间隔」
- [x] 1.6 `ScreenHTML.version` 提升到 `2026-11-27.8`

## 2. 保留

- [x] 2.1 保留 `Docs/design/pet-chase-candidates/` 与设计文档
- [x] 2.2 `THIRD_PARTY_NOTICES.md` 标注为设计候选、未随包分发

## 3. 验证

- [x] 3.1 `swift test --filter ScreenDisplay` 通过
- [x] 3.2 副屏只剩单只游走，无 `#petChase` 节点、无 `petChase` 字段
- [x] 3.3 固定签名构建 + 覆盖安装 + DR 校验通过
