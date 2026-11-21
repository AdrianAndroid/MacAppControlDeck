# 任务清单：add-desktop-pet

## Phase 0：规格
- [x] 0.1 新建 OpenSpec proposal
- [x] 0.2 新建 design
- [x] 0.3 新建 desktop-pet spec delta
- [x] 0.4 新建 tasks

## Phase 1：模块骨架
- [x] 1.1 新增 PetModule / PetRuntime / PetSettings
- [x] 1.2 注册模块到 DeckApp
- [x] 1.3 新增 pet.open 内置操作
- [x] 1.4 新增 ⌃⌥P 全局快捷键
- [x] 1.5 模块菜单与设置入口

## Phase 2：面板与拦截
- [x] 2.1 PetPanel / PetPanelController
- [x] 2.2 PetGeometry 三档尺寸与位置
- [x] 2.3 hit path 与动态点击穿透
- [x] 2.4 多屏位置恢复与夹回

## Phase 3：皮肤与渲染
- [x] 3.1 PetSkin / 五套皮肤目录
- [x] 3.2 PetSceneView 矢量画猫/狗/键盘
- [x] 3.3 键盘主题与区域高亮
- [x] 3.4 换肤/尺寸动画与 hit path 同步

## Phase 4：输入与状态机
- [x] 4.1 PetInputMonitor CGEventTap
- [x] 4.2 PetKeyZone 分区映射
- [x] 4.3 PetStateMachine 动作/表情/睡觉
- [x] 4.4 动画时钟与帧率控制
- [x] 4.5 Secure Input / 锁屏 / 休眠暂停

## Phase 5：交互与设置
- [x] 5.1 拖拽、右键菜单、锁定、点击穿透
- [x] 5.2 设置页皮肤/尺寸/主题/行为/权限
- [x] 5.3 首启提示
- [x] 5.4 菜单状态勾选与 R0 入口验证

## Phase 6：系统边界
- [x] 6.1 全屏/多桌面策略
- [x] 6.2 自带截图/录屏隐藏（可选通知）
- [x] 6.3 低电量/减弱动态效果
- [x] 6.4 显示器变化处理

## Phase 7：测试
- [x] 7.1 PetGeometryTests
- [x] 7.2 PetSkinCatalogTests
- [x] 7.3 PetStateMachineTests
- [x] 7.4 PetSettingsTests
- [x] 7.5 PetRuntimeTests
- [x] 7.6 swift test 全通过
- [x] 7.7 Build/build.sh 签名成功
- [x] 7.8 实机截图与权限/多屏验证

## Phase 8：文档与归档
- [x] 8.1 README 与架构文档
- [x] 8.2 Docs/archive SUMMARY
- [x] 8.3 OpenSpec 归档并同步 specs
- [x] 8.4 git 提交
