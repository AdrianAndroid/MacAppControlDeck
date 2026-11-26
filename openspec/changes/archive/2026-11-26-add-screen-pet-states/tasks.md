# Tasks

- [x] 设计文档（Docs/plans/2026-11-26-screen-pet-states.md，含性能审计）
- [x] ① 单 rAF（宠物 30fps / 时钟 1fps）、尺寸缓存、零 SVG 重建
- [x] ② 状态机 + 道具层（Zzz / 伞 / 围巾 / 汗滴 / 表 / 星）
- [x] ③ 数据钩子：/api/time、/api/weather、/api/screen/countdown
- [x] ④ `petLive` 开关（Swift 配置 + 设置页 + 页面）
- [x] ⑤ QA 参数 `?petState=`，逐状态 headless 截图核对（rain / sleep / cold / hot / packup / celebrate）
- [x] ⑥ 回归：`swift test --filter "ScreenDisplay|APIRouter"` 20/20；固定签名构建 + 覆盖安装
- [x] 真机观感确认（三档尺寸、长时间常亮）
