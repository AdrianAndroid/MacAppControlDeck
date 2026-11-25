# Tasks

- [x] 设计（单行 + 拖动滚动、条宽收缩居中、点击频率排序、不跳位）与能力 delta
- [x] PetDockSettings / PetDockStats（衰减 + 冷却 + 最近点击标记）
- [x] PetDockCenter（独立透明小窗口、跟随宠物、订阅 `DeckState.$buttons` 重排／隐藏）
- [x] PetDockView（单行 + 统一手势 + 边缘渐隐 + 悬停态 + 运行点 + 最近点击变浅）
- [x] PetPanelController 挂接 show/hide/shutdown 与位置同步
- [x] PetSettingsView 新增「底部快捷栏」设置卡
- [x] 构建 + 固定签名覆盖安装，截图确认位置、间距与居中
- [x] 去掉单格底框，改为「一层胶囊 + 悬停高亮」
- [x] 收紧间距（2pt）与内边距（上下 6 / 左右 4），条宽随图标数量收缩
- [x] 回归：`swift test --filter PetPanelControllerTests`（4/4）
- [ ] 真机点按与横向拖动的手感确认（由用户在桌宠所在空间验收）
