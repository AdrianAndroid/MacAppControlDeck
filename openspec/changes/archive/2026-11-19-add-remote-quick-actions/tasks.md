# 任务清单：add-remote-quick-actions

> 当前为设计阶段，本清单全部未开始。实现前先确认设计（design.md）无异议。

## 1. 数据模型与迁移

- [x] 1.1 `ButtonConfig` 增加 `kind`（app/shortcut）与 `shortcut`（modifiers/keyCode/keyLabel），旧 JSON 兼容（kind 缺省为 app）
- [x] 1.2 组合结构：修饰键集合（command/control/option/shift/function）+ 主键 keyCode + 展示 keyLabel；写入前归一化
- [x] 1.3 组合符号生成器（⌃⌥⇧⌘ 固定顺序；方向键/回车/Esc 特殊符号）
- [x] 1.4 配置读写升级：`GET /api/buttons` 输出 `kind`/`symbol`/`group`；旧配置读取后以 v2 结构回写
- [x] 1.5 单元测试：旧配置迁移、组合往返、符号生成、未知字段容错

## 2. 快捷键注入（KeyInjector）

- [x] 2.1 `KeyInjector`：CGEvent down/up + flags 注入，60ms 间隔，`.cghidEventTap`
- [x] 2.2 权限与安全输入检查：`AXIsProcessTrusted()` / `IsSecureEventInputEnabled()`，失败返回明确错误码
- [x] 2.3 预设常量表（桌面左/右、复制、粘贴、全选、撤销、回车、Esc、F1–F12）与 UI/测试共用
- [x] 2.4 执行结果语义：`sent`（事件已发出）与失败原因；不承诺目标应用响应
- [x] 2.5 单元测试：映射表完整性、组合校验（空主键/重复/修饰键归一化）

## 3. API 与路由

- [x] 3.1 `/api/activate` 按按钮类型分派：应用按钮走 AppControl，快捷操作走 KeyInjector
- [x] 3.2 响应字段扩展：`kind`、`status`（`sent` / `shortcut-failed`）、`error` 与中文 `message`
- [x] 3.3 错误码：`accessibility-required`、`secure-input`、`injection-failed`、`bad-button-config`
- [x] 3.4 集成测试：两类按钮请求、未知按钮、组合字段禁入请求体、未授权路径

## 4. Mac 端 UI

- [x] 4.1 「添加按钮」拆分为菜单：添加应用按钮… / 添加快捷操作…
- [x] 4.2 添加快捷操作 Sheet：预设清单（图标+符号+名称）
- [x] 4.3 自定义编辑器：修饰键切换 + 主键下拉 + 实时符号预览 + 保存校验（空/重复）
- [x] 4.4 录制模式：`NSEvent.addLocalMonitorForEvents` 捕获组合，纯修饰键不结束、Esc 取消
- [x] 4.5 按钮列表：类型标签；快捷操作行支持编辑组合/重命名/删除（确认）
- [x] 4.6 分组内排序（应用与快捷操作互不影响）

## 5. 手机面板

- [x] 5.1 分组渲染：「应用」与「快捷操作」两个 section；空分组不渲染
- [x] 5.2 快捷操作按钮样式：组合符号大字 + 名称；桌面按钮显示方向符号
- [x] 5.3 触发状态文案按类型区分：正在发送…/已发送快捷键/需要辅助功能权限/安全输入模式
- [x] 5.4 交互保护：请求期间仅禁用被点击按钮，防止重复触发

## 6. 文档与验收

- [x] 6.1 更新 README：新增按钮类型、快捷操作使用说明、权限/安全输入/F 键/桌面切换限制
- [x] 6.2 真机验收：复制/粘贴、F1/Esc（普通应用）、桌面左右切换、命令按钮(Snipaste)、Launchpad 文案通过；密码框安全输入场景未专门验证
- [x] 6.3 归档变更并同步主规格

## 实现补充（2026-11-19）

- [x] 7.1 全局热键类应用改由「命令按钮」触发（Snipaste `snip` 实测通过）
- [x] 7.2 桌面左右切换改走 System Events（需「自动化」权限），实测循环与边界正常
- [x] 7.3 随包 CLI 助手 KeySender 与回归测试；单元测试 26 项通过
- [x] 7.4 权限矩阵 UI（辅助功能 / 输入监控 / 自动化 / 调度中心开关）
