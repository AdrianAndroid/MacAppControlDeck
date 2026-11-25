# 任务清单：fix-buttons-grid-drag-ghost

- [x] 1. 把 `DragGesture` 从单张卡片移到每组 `LazyVGrid` 容器
- [x] 2. 用按下起点 frame 命中按钮，保持点击选中、长按、拖动状态机
- [x] 3. 确认卡片右键菜单、hover、help、辅助功能动作不受影响
- [x] 4. `swift test --filter ButtonGridReorderTests`：7 项通过
- [x] 5. `./Build/build.sh` 与固定签名校验通过（CDHash `02eafe8eac7be1b3c7516f1c5d1c6445b80ee6fe`）
- [x] 6. 系统级鼠标回放：按住 0.75s 后拖动，拖动中截图确认浮层跟手、占位空隙实时更新
- [x] 7. 同步 `openspec/specs/button-panel-config/spec.md`
- [x] 8. 归档变更

## 验证记录

- 拖动中截图：`/tmp/buttons-drag-live.png`（临时证据，不提交仓库）。
- 拖回原位松手，不改动按钮顺序。
