# 任务清单：add-desktop-pet-v4-raster-rig

> 状态：已完成（单帧方案收敛）。`[x]` 已交付；`[~]` 与计划不同或不做，右侧写明原因。

## 0. 基线整理

- [~] 0.1 未单独 stash 未提交改动：V2 微调（README、`PetAnimationClock`、`PetRig`、`PetStateMachine`、`PetTypes`、`PetVectorArt`）直接在 `main` 工作区叠加，未产生独立提交
- [~] 0.2 未开 `feat/desktop-pet-v4-raster-rig` 分支：按要求在 `main` 上完成，提交说明引用 change-id
- [x] 0.3 确认并锁定参考资产：`desktop-pet-v4-desk-keyframe`、`typing-down`、`mouse`、`gaze-right`、`keycap-motion-board`、`gaze-motion-board`
- [x] 0.4 基线 `swift test` 90 项通过、`./Build/build.sh` 可出包
- [x] 0.5 proposal / design / tasks / spec delta 齐备

## 1. 资产生产

- [x] 1.1 1373×1717 母版 → 1440×1920 工作画布（S = 1440/1373）
- [x] 1.2 去米色墙（`scene_al = (1-above) + 0*lum`），桌板保留，底边 180px alpha 垂直淡出
- [x] 1.3 拆 `scene`（桌板+猫身+键鼠）、`head`、`keycap` 三层（最终未把 table/keyboard/mouse 独立成层，理由见 4 节偏差）
- [x] 1.4 拆 `eyeL`、`eyeR`（眼窝外扩 1.7 倍椭圆裁剪，保留高光与虹膜）
- [~] 1.5 未做 `lidL`/`lidR` 闭眼层：现有眨眼沿用矢量皮肤逻辑，v4 只做眼球位移
- [~] 1.6 未做 `armL-*`/`armR-*` 姿态层：三帧无法对齐，见 4 节
- [x] 1.7 `keycap.png` 90×80 白键帽，字符由 Canvas 运行时叠加
- [x] 1.8 头部 polygon ∩ alpha>0.5 收边（feather 1.5），颈根不留缝
- [x] 1.9 输出 @2x straight-alpha PNG
- [x] 1.10 2× 目检接缝：删除 41px 毛发膨胀 margin，避免墙面灰光晕与直线接缝
- [x] 1.11 `manifest.json`：designSize、scale、各层 origin/size、neck、eyes、pupilRange、keycap slots、riseY、life、headRotate
- [x] 1.12 载入校验：文件存在 + 解码成功，失败整体回退矢量
- [x] 1.13 合成 720×960 透明待机图与主视觉并排比对通过

## 2. 渲染骨架

- [x] 2.1 `PetRasterManifest`（Decodable）解码 manifest
- [x] 2.2 `PetRasterAssets`（懒加载 PNG，候选路径 bundle `v4/`、资源根 `v4/`、bundleURL，全失败返回 nil）
- [x] 2.3 尺寸/坐标：720×960 → 三档 230×307 / 288×384 / 374×499
- [x] 2.4 `PetRasterFrame`（eyeX/eyeY/headYaw/headPitch/bob/keycaps）承载状态
- [x] 2.5 `PetRasterRenderer.draw` 按 z 序：scene → head(旋转+平移, 内含双眼) → keycaps
- [x] 2.6 `PetStateMachine` 增加 `rasterFrame`、`gazeCursorX/Y`、`handleGaze(normalizedX:normalizedY:)`
- [x] 2.7 `PetSceneView` / `PetLivePreview` 有素材走光栅，否则走矢量
- [x] 2.8 `Package.swift` `.copy("Modules/Pet/Resources/v4")`，产物在 `Contents/Resources/...bundle/v4`
- [x] 2.9 实机：透明、无墙、无矩形底、三档不裁切
- [x] 2.10 资产缺失自动回退矢量，不 crash

## 3. 全屏视线与头部

- [x] 3.1 复用 30fps hover 定时器读取 `NSEvent.mouseLocation`
- [x] 3.2 `normalizedGazePosition()` 用宠物所在屏 `visibleFrame` 归一化
- [x] 3.3 归一化后 clamp 到 0…1
- [x] 3.4 瞳孔 ±10 / ±6 pt，stiffness 520 / damping 34
- [x] 3.5 头部 yaw ±3° / pitch ±2.2°，stiffness 150 / damping 26
- [x] 3.6 鼻尖位移由 yaw/pitch 上限天然约束
- [~] 3.7 未做身体侧倾 ±1°：单帧场景下身体不独立，呼吸浮动 1.6pt 顶替
- [x] 3.8 优先级：打字时 gazeY +0.22 看向键盘；待机回中
- [x] 3.9 `followMouse` 关闭与 Reduce Motion 沿用现有开关语义
- [x] 3.10 Secure Input / 锁屏 / 休眠冻结并由暂停逻辑回正
- [x] 3.11 单测更新：几何/状态机 90 项通过

## 4. 姿态混合（收敛为单帧）

- [~] 4.1–4.8 全部不做：`typing-down` 相对 idle 整体低 106px（2x）、桌面线差 35px、`mouse` 帧只有单眼，整场景交叉淡化实测双影
- [x] 替代实现：单帧 scene + 头部偏转 + 视线下压 + 键帽反馈；按鼠标只做头偏 1.5°
- [x] 偏差已写入 `specs/desktop-pet/spec.md`「单帧场景与头部/键帽反馈」

## 5. 键帽

- [x] 5.1 6 槽 / 0.44s → 4 槽 / 0.6s（`keycapSlots`、`keycapLife` 常量）
- [x] 5.2 生命周期 0–80ms 升起、80–420ms 悬浮、420–600ms 上浮 13px + 淡出
- [x] 5.3 scale 0.85→1.0（0–80ms），淡出阶段 →1.2
- [x] 5.4 超出 4 个移除最旧
- [x] 5.5 槽位写入 manifest：`(600,300,-5)`、`(905,205,4)`、`(1200,330,-3)`、`(1030,390,3)`
- [x] 5.6 字符取 `PetKeyMap.label`，字母/数字/符号/修饰键均可
- [x] 5.7 `GraphicsContext.draw(Text)` 17pt semibold，随键帽旋转/缩放/淡出
- [~] 5.8 未按档位缩小字号：17pt（设计坐标）随整体缩放，最小档实测可读
- [x] 5.9 不写日志、不持久化、不记录文本
- [x] 5.10 单测：待机 0 个、连打最多 4 个、0.6s 清空、标签正确

## 6. 时钟、生命周期与性能

- [x] 6.1 `PetAnimationClock` 活动 20fps → 30fps，空闲 2fps
- [~] 6.2 未设 15fps 中间档：活动 0.9s 后直接回 2fps，避免多余跳档
- [x] 6.3 隐藏/锁屏/录制隐藏时停表释放
- [x] 6.4 素材常驻内存、按需解码，帧内不重建 NSImage
- [x] 6.5 窗口尺寸迁移：288×384 / 230×307 / 374×499，窗口 +8pt
- [x] 6.6 旧位置归一化后 clamp，不跳屏
- [x] 6.7 `PetSettingsView` 有素材时以说明行替代皮肤/键盘主题选择器
- [x] 6.8 实测静止与活动 CPU/内存正常（30fps 光栅合成无掉帧）

## 7. 验证

- [x] 7.1 `swift test` 90 项 0 失败
- [x] 7.2 `./Build/build.sh` release + 自签名通过
- [x] 7.3 覆盖安装 `/Applications/MacAppControlDeck.app` 并启动
- [x] 7.4 深色桌面实拍：无墙面、无矩形底、底边自然淡出
- [x] 7.5 2× 目检颈根、腋下、尾根无接缝
- [x] 7.6 连续移动光标（瞳孔左右跟随）、连按修饰键（4 个字符键帽）实拍通过
- [~] 7.7 五皮肤切换在 v4 下不适用（入口收起），三档尺寸与点击穿透实机确认
- [~] 7.8 无输入监控权限 / Secure Input 降级沿用 V2 已验证路径，本次未重测
- [x] 7.9 关闭/重开桌宠，窗口与监听即时释放
- [~] 7.10 未做 1 小时长时观察（本轮时间窗内完成短时观察，无增长）

## 8. 文档与归档

- [x] 8.1 README 桌面宠物章节改 v4 行为、尺寸、透明度、限制
- [x] 8.2 `Docs/design/desktop-pet-v4-layer-spec.md`
- [x] 8.3 `Docs/archive/2026-11-21-desktop-pet-v4/SUMMARY.md`
- [x] 8.4 `openspec/specs/desktop-pet/spec.md` 同步
- [x] 8.5 归档到 `openspec/changes/archive/2026-11-21-add-desktop-pet-v4-raster-rig/`
- [x] 8.6 提交说明引用 `add-desktop-pet-v4-raster-rig`，写明沿用 `pet.open`、无新增入口
- [x] 8.7 提交到 `main`

## 9. 回滚

- [x] 9.1 资产目录缺失即自动回矢量（等效 `renderV4=false`），用户设置不丢
- [x] 9.2 v4 资源目录可整体删除，编译不受影响
- [x] 9.3 V2 矢量视图与五皮肤完整保留一个发布周期
