# 任务：设置页深链接与安装后直接打开桌宠设置

## 1. 实现

- [x] 1.1 `Build/Info.plist` 注册 `macappcontroldeck` URL scheme
- [x] 1.2 `DeckApp` 处理 `application(_:open:)`，支持 `settings/<tab>` 与 `settings?tab=<tab>`，启动完成前的请求延后执行
- [x] 1.3 安装脚本安装成功后 `open macappcontroldeck://settings/pet`，失败弹窗给手动路径
- [x] 1.4 安装脚本加 EXIT trap，未预期失败也弹窗

## 2. 验证

- [x] 2.1 `swift build -c release` 通过
- [x] 2.2 安装新构建后 `open macappcontroldeck://settings/pet` 能打开设置并停在桌面宠物页
- [x] 2.3 沙箱运行安装脚本，成功后有弹窗提示且桌宠被拉起/设置被打开
- [x] 2.4 重打 arm64 DMG，确认脚本与说明已更新
- [x] 2.5 签名校验仍为稳定自签名
