# 一级菜单按模块重构 + 置顶命令 + 默认应用/快捷启动

日期：2026-11-20
归档时状态：已提交、已安装验证；工作区干净

涉及提交：

- `68888e6` 菜单重构：一级菜单按模块分类并支持常用命令定制
- `eab7fee` 默认应用/默认快捷启动、递归收集置顶、默认置顶命令
- `e607739` 置顶命令顺序可在设置页调整

---

## 1. 需求与目标

### 1.1 一级菜单按功能模块分类

- 一级菜单不再把所有功能堆在一个「电脑控制」入口里。
- 每个功能模块提供一个一级根子菜单；「电脑控制」与「截图与录屏」同级。
- 模块顺序、模块内命令顺序、命令隐藏状态全部可定制并持久化。

### 1.2 「常用置顶」必须点开即用

用户明确否决了「常用」二级菜单方案：

> 置顶的功能就在一级菜单显示，打开下拉菜单直接就能使用，不用再打开二级菜单，目的就是使用便利。

最终实现为：置顶命令直接克隆、平铺在一级下拉顶部，下方一条分隔线，再列各模块根子菜单。

### 1.3 默认内容

- 为「电脑控制」预置几个默认应用。
- 预置几个默认快捷启动。
- 预置几条默认置顶功能，首次运行即可用。

### 1.4 置顶顺序可调

- 设置页可以单独调整置顶命令的先后顺序，而不是只能由模块/命令顺序间接决定。

---

## 2. 最终菜单结构

```
┌ 置顶命令（平铺，点开即用，按设置页保存顺序）
│  区域截图
│  复制选中            ⌘C
│  在浏览器打开面板
│  全屏截图
│  调度中心            ⌃↑
├────────────
├ 电脑控制 ▸
│    面板：192.168.18.159:47615（不可点）
│    在浏览器打开面板
│    复制面板地址
│    应用 ▸ 豆包 / Firefox / Chrome / Clash Verge
│    快捷操作 ▸ 显示桌面 / 调度中心 / 切换应用 / 复制选中
│    配对手机…
│    重启服务
├ 截图与录屏 ▸
│    全屏截图 / 区域截图 / 窗口截图 / 延时 / 滚动 …
├────────────
├ 设置…
├────────────
└ 退出 Mac 应用快捷控制台
```

置顶项来自任意层级子菜单，包括「应用」「快捷操作」里的按钮项。

---

## 3. 代码结构变化

| 文件 | 变化 |
|---|---|
| `Core/MenuCustomization.swift` | 模块顺序、命令顺序、隐藏、置顶顺序；`menu.module.order`、`menu.order.<moduleID>`、`menu.hidden.<moduleID>`、`menu.pinned`、`menu.defaults.v1` |
| `UI/MenuSettingsView.swift` | 新增「菜单」设置页：模块排序、显示开关、命令上下移、星标；顶部新增「置顶命令」卡片，支持置顶项独立上下移与取消置顶 |
| `UI/MenuBarController.swift` | 每个模块生成一级子菜单；原地 `removeAllItems()` 后重排；平铺置顶；递归 `collectPinned`；按保存的置顶顺序排序 |
| `Modules/RemoteControl/RemoteControlModule.swift` | 「电脑控制」根菜单；应用/快捷操作收进二级子菜单；所有菜单项写入稳定 identifier |
| `Modules/Capture/CaptureModule.swift` | 截图/录屏菜单项写入稳定 identifier |
| `Store/ConfigStore.swift` | `seedDefaultButtons(firstLaunch:)`：默认应用与默认快捷启动；一次性种子标记，删光后不会自动加回 |
| `UI/SettingsView.swift` | 新增 `.menu` 标签与左侧「菜单」入口 |
| `App/DeckState.swift` | `menuTitle(for:)` 统一模块显示名 |

### 3.1 稳定 ID 规则

- 模块根：`remote.root`、`capture.root`
- 电脑控制命令：`remote.address`、`remote.openPanel`、`remote.copyPanel`、`remote.pair`、`remote.restart`
- 应用按钮：`remote.apps.<button.id>`
- 快捷操作按钮：`remote.shortcuts.<button.id>`
- 截图命令：`capture.<命令标题 slug>`

### 3.2 置顶存储

- `menu.pinned` 从 `Set` 改为**有序数组**，数组顺序就是一级菜单顶部顺序。
- 新增置顶项追加到末尾；取消置顶从数组移除。
- 菜单装配时按 `menu.pinned` 排序，未知/失效 ID 不渲染。
- `menu.defaults.v1` 保证默认置顶只合并一次，之后用户取消不会再加回。

---

## 4. 默认内容

### 4.1 默认应用（仅全新安装）

按存在性取前 4 个：

1. 访达 `/System/Library/CoreServices/Finder.app`
2. Safari `/Applications/Safari.app`
3. 终端 `/System/Applications/Utilities/Terminal.app`
4. Google Chrome `/Applications/Google Chrome.app`

> 老用户已有应用配置不覆盖。当前机器保留豆包、Firefox、Chrome、Clash Verge 四个应用。

### 4.2 默认快捷启动

| 名称 | keyCode | 按键 | 修饰键 | 稳定 ID |
|---|---|---|---|---|
| 显示桌面 | 103 | F11 | 无 | `default.shortcut.showDesktop` |
| 调度中心 | 126 | ↑ | control | `default.shortcut.missionControl` |
| 切换应用 | 48 | Tab | command | `default.shortcut.switchApp` |
| 复制选中 | 8 | C | command | `default.shortcut.copy` |

老配置首次升级时补齐默认快捷启动；若已有任意快捷启动则不追加，避免覆盖用户配置。

### 4.3 默认置顶

`MenuCustomization.defaultPinnedIDs`：

- `capture.全屏截图`
- `capture.区域截图`
- `remote.shortcuts.default.shortcut.missionControl`
- `remote.shortcuts.default.shortcut.copy`

当前用户配置里另有此前置顶的 `remote.openPanel`，因此实际顶部显示 5 条。默认置顶已移除不存在的 Finder 项。

---

## 5. 过程中踩的坑与修复

### 5.1 把旧 `NSMenu` 的 `NSMenuItem` 直接搬进新菜单会崩

- 现象：状态栏图标点击后菜单不弹出，装配中断。
- 根因：AppKit 不允许把旧菜单里的 item 直接加入另一个新 `NSMenu`，会抛异常。
- 修复：原地 `submenu.removeAllItems()`，再按保存顺序重新 `addItem`；重复 command ID 追加 `#2` 后缀。

### 5.2 子菜单里的按钮无法置顶

- 现象：应用/快捷操作按钮星标后，一级顶部不出现。
- 根因：`customized` 只遍历模块根子菜单的顶层 `items`，不会递归进入「应用」「快捷操作」子菜单。
- 修复：新增递归 `collectPinned(in:into:)`，遍历任意层级，按 identifier 去重收集。

### 5.3 默认置顶指向不存在的应用

- 现象：默认 Finder 置顶永远不显示。
- 根因：老用户配置不会新增默认应用，本机没有 Finder 按钮项。
- 修复：`defaultPinnedIDs` 移除 Finder；默认置顶只保留实际存在的高频命令。

### 5.4 置顶顺序由模块顺序决定，设置页改不了

- 现象：星标只能决定“是否置顶”，先后顺序由模块/命令遍历顺序决定。
- 修复：`menu.pinned` 改为有序数组；设置页新增「置顶命令」卡片；菜单装配前按保存顺序排序。

### 5.5 默认快捷启动删光后又被加回

- 风险：仅以“当前没有快捷启动”判断迁移，会导致用户主动删光后每次启动都重新补默认项。
- 修复：新增 `config.defaults.seeded.v1` 一次性标记；首次升级补一次后永不再补。

---

## 6. 验证

- `swift build -c release` 无 error。
- `./Build/build.sh` 成功组装并自签名；安装到 `/Applications/MacAppControlDeck.app`。
- 健康检查：`/api/health` 返回 `{"app":"MacAppControlDeck","ok":true,"version":"0.1.0"}`。
- 一级菜单实际显示 5 条平铺置顶：区域截图、复制选中、在浏览器打开面板、全屏截图、调度中心。
- 「电脑控制」二级菜单包含面板地址、打开面板、复制地址、应用、快捷操作、配对、重启。
- 设置页「置顶命令」卡片显示 5 条，实际把「区域截图」从第 2 位上移到第 1 位，`menu.pinned` 数组顺序同步变化，重新打开菜单后顺序生效。
- 归档截图：`Docs/verification/menu-refactor/01`–`08`。

## 7. 验收截图

| 文件 | 内容 |
|---|---|
| `01-一级菜单-置顶直显.png` | 模块同级 + 置顶平铺 |
| `02-电脑控制.png` | 电脑控制二级菜单 |
| `03-截图与录屏.png` | 截图与录屏二级菜单 |
| `04-菜单定制设置.png` | 菜单定制设置页 |
| `05-默认置顶命令.png` | 默认置顶后的顶部菜单 |
| `06-电脑控制默认入口.png` | 应用/快捷操作入口 |
| `07-置顶顺序设置.png` | 置顶命令排序面板 |
| `08-置顶顺序生效.png` | 排序后一级菜单实际顺序 |

---

## 8. 遗留与边界

- 默认快捷启动（显示桌面、调度中心、切换应用、复制选中）已验证菜单项存在，**未逐条实际点击验证快捷键注入效果**。
- 全新安装首次种子的默认应用（访达/Safari/终端/Chrome）未做隔离环境验证，避免破坏当前用户 `buttons.json`。
- `menu.pinned` 中仍可能残留历史失效 ID（如 Finder 按钮）；当前不渲染、不影响使用，未强制清理。
- 模块对外名称「电脑控制」与架构文档旧称「电脑遥控」尚未统一；需用户确认最终命名后再改文档。
