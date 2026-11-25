# 任务清单：remove-buttons-grid-selection-bar

- [x] 1. 删除底部 `selectionBar` 与 `safeAreaInset`
- [x] 2. 清理 `selectedButton`、`iconName(for:)` 等仅操作条使用的代码
- [x] 3. 点击仍高亮选中；右键菜单保留重命名/编辑组合/上移/下移/删除
- [x] 4. 更新底部说明文字
- [x] 5. `swift test --filter ButtonGridReorderTests`
- [x] 6. `./Build/build.sh` 与固定签名校验
- [x] 7. 实机确认底部操作条消失、最后一行不再被遮挡
- [x] 8. 同步 `openspec/specs/button-panel-config/spec.md`
- [x] 9. 归档变更
