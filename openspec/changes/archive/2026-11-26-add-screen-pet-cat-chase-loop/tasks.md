# 任务：副屏宠物卡「猫追老鼠」

## 1. 素材

- [x] 1.1 从 OpenGameArt 导出猫 6 帧、鼠 3 帧，去底、裁 bbox、调色
- [x] 1.2 生成两条帧条 strip（猫 120×16、鼠 75×14）
- [x] 1.3 转 base64 内联进 `Screen/index.html`，注释写明出处与重建方法
- [x] 1.4 `THIRD_PARTY_NOTICES.md` 补鼠的 CC-BY 3.0 署名

## 2. 实现

- [x] 2.1 新增 `#petChase` 层与两只精灵，与 `#petWalker` 互斥
- [x] 2.2 CSS `steps()` 帧动画 + `background-position-x` 百分比，随尺寸档自适应
- [x] 2.3 追逐状态机：idle 触发、7 秒结束、`nextAt` 冷却
- [x] 2.4 一对刚体位移 + 触边镜像 + 朝向翻转
- [x] 2.5 `petStep` 单循环接入，每帧只写 transform
- [x] 2.6 非 idle 状态与关闭开关时立即停止并恢复游走
- [x] 2.7 `ScreenHTML.version` 提升到 `2026-11-27.7`

## 3. 设置

- [x] 3.1 `ScreenDisplayConfig` 增 `petChase` / `petChaseInterval`
- [x] 3.2 `ScreenDisplaySettings` 增键与归一化
- [x] 3.3 副屏设置页增开关与间隔分段
- [x] 3.4 `/api/screen/display` 下发新字段

## 4. 验证

- [x] 4.1 `swift test --filter ScreenDisplay` 通过
- [x] 4.2 headless 截图：三档尺寸下鼠在猫前方、不重叠
- [x] 4.3 关闭开关 / 非 idle 状态无追逐层
- [x] 4.4 CPU 与改动前持平（单 rAF、零布局读取）
