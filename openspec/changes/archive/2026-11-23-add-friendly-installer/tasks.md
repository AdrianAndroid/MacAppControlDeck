# 任务：发布包内置双击安装脚本

## 1. 实现

- [x] 1.1 新增 `Build/install-friendly.command`：定位 App、架构校验、复制、去隔离、签名兜底、启动、结果弹窗
- [x] 1.2 新增 `Build/install-readme.txt`：双击步骤、右键打开兜底、菜单栏与桌宠说明
- [x] 1.3 `Build/package-release.sh` 把两个文件打进 DMG，脚本置为可执行

## 2. 验证

- [x] 2.1 沙箱（`DECK_INSTALL_DIR=/tmp/...`）安装成功，目标 App 的 quarantine 被清除
- [x] 2.2 找不到 App 时退出码 1 并弹窗说明
- [x] 2.3 从挂载的 DMG 内直接运行脚本，安装到沙箱目录成功
- [x] 2.4 重打 arm64 包，确认 DMG 内含脚本与说明且脚本可执行
- [x] 2.5 本机 `/Applications` 安装与签名校验不受影响
