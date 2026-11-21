# 技术设计：区域截图图标与设置信息架构

## 菜单图标

- `CaptureModule` 的菜单项统一通过 `item(_:_:_:)` 创建。
- 「区域截图」原使用 `NSImage(systemSymbolName: "selection")`，该名称在本机 macOS 15.8 上返回 nil，导致子菜单和置顶克隆项都没有图标。
- 改为 `rectangle.dashed`，并已用 AppKit 验证该符号存在。
- `MenuBarController.clone(_:)` 会复制 `item.image`，所以置顶项与子菜单项会同步恢复图标，不需要额外改置顶逻辑。

## 设置侧栏

```text
应用
├── 通用         应用级：启动、数据与日志
└── 菜单         菜单栏项目顺序/置顶
模块
└── 模块         模块启用与常驻
电脑控制
├── 服务         远程面板、权限、设备配对
├── 按钮         手机面板/菜单栏按钮配置
└── 设备         已配对设备管理
截图与录屏
UI 草图
万年历
关于
```

- `SettingsTab` 新增 `.remoteService`。
- `GeneralSettingsView` 改为应用级：
  - 登录时自动启动；
  - 数据目录、日志目录与 Finder 打开按钮。
- `RemoteServiceSettingsView` 承接原通用页中的远程面板、权限卡、配对卡和 HTTP 安全提示。
- `RemoteControlModule.pairPhone` 打开 `.remoteService`。
- 设备空状态提示改指向「服务」。

## 验收

- 菜单栏「区域截图」子菜单项与置顶项都显示 `rectangle.dashed` 图标。
- 设置「通用」页不再出现远程面板、权限、配对。
- 「电脑控制 → 服务」页完整保留原远程面板、权限、配对内容与操作。
- 配对手机动作跳到「服务」页。
- `swift test`、`./Build/build.sh` 通过，覆盖安装后截图确认。
