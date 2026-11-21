# 任务清单：add-readme-feature-screenshots

## 1. 需求盘点

- [x] 1.1 通读 README，标记菜单栏、设置、截图录屏、UI 草图、手机端等待补图位置
- [x] 1.2 盘点 `Docs/archive` 与 `Docs/verification` 已有截图，确定可复用与需重拍清单
- [x] 1.3 确定截图目录 `Docs/images/readme/` 与 14 张英文命名

## 2. 实机截图

- [x] 2.1 截菜单栏主菜单，确认包含区域截图、复制选中、在浏览器打开面板、全屏截图、调度中心、电脑控制、截图与录屏、UI 草图、设置、退出
- [x] 2.2 截电脑控制子菜单
- [x] 2.3 截截图与录屏子菜单，覆盖全屏/区域/窗口/滚动截图、OCR、录屏、GIF、最近截图
- [x] 2.4 截设置页：通用、菜单、模块、截图与录屏、UI 草图、设备
- [x] 2.5 通过真实 `builtin.capture.area` 触发区域截图，截取选区覆盖层并裁剪
- [x] 2.6 复用已验证的 UI 草图板与精选素材库截图

## 3. 手机端截图

- [x] 3.1 无头 Chromium 按 iPhone 390×844（2×）视口打开配对页并截图
- [x] 3.2 读取本机已有设备 token，注入 `localStorage`，打开真实已配对面板
- [x] 3.3 确认面板请求真实 `/api/buttons`，不使用假按钮数据
- [x] 3.4 确认 token 未写入仓库、未输出到对话

## 4. 图片处理

- [x] 4.1 设置窗口由 952×832 裁为 840×720
- [x] 4.2 菜单截图只裁菜单面板，重新合成浅灰背景并加阴影
- [x] 4.3 手机图压到 700 px 宽；画板/素材库最大 1200 px
- [x] 4.4 全部 PNG 优化，14 张合计约 1.4 MB
- [x] 4.5 README 中手机长图使用 HTML `width` 限制展示尺寸

## 5. README 改写

- [x] 5.1 顶部增加菜单栏 + 手机面板双栏总览
- [x] 5.2 Mac 端使用插入主菜单与电脑控制子菜单
- [x] 5.3 新增「截图、录屏与视频剪辑」章节与 5 步使用路径
- [x] 5.4 新增「UI 草图」章节与 5 步使用路径
- [x] 5.5 手机端插入配对页与已配对面板
- [x] 5.6 新增「设置界面」章节，展示六页设置
- [x] 5.7 修正测试数量 40 → 51

## 6. 验证

- [x] 6.1 README 中 14 个 `<img src>` 路径全部存在，无死链
- [x] 6.2 GitHub raw 抽查图片返回 `200`
- [x] 6.3 本地 `main` 与 `origin/main` 指向同一提交，工作区干净
- [x] 6.4 确认本次仅文档与图片变更，未重跑 `swift test`；README 数量与最近测试结果一致
- [x] 6.5 确认没有把桌面无关窗口、聊天记录、token 写入截图或仓库

## 7. 归档与提交

- [x] 7.1 新增 `Docs/archive/2026-11-21-readme-screenshots/SUMMARY.md`
- [x] 7.2 新增 OpenSpec 归档 `openspec/changes/archive/2026-11-21-add-readme-feature-screenshots/`
- [x] 7.3 新增 `openspec/specs/project-documentation/spec.md`
- [x] 7.4 README「归档」索引加入 Docs 与 OpenSpec 链接
- [x] 7.5 提交并推送 `main`
- [x] 7.6 提交说明写明“无用户可见入口”
