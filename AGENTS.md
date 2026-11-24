# AGENTS.md · 项目开发规则

本文件是后续任何开发（人类或 Agent）都必须遵守的项目级规则。

## R0. 每个新功能都必须有内置的快捷打开按钮

新增任何用户可见的功能、窗口、面板或模块时，必须同时提供 **开箱可用的内置快捷入口**，不能只藏在设置页、二级菜单或一行文档里。

### 强制清单

1. 在 `Sources/MacAppControlDeck/Control/BuiltinActions.swift` 的 `all` 中注册：
   - `id` 使用 `<feature>.open`，例如 `sketch.open`
   - `name` 使用「打开 X」，例如「打开 UI 草图」
   - `symbol` 提供一个易辨识字符
2. 在 `BuiltinActions.run` 的 `switch` 中接上实际打开动作。
3. 保证该入口在「设置 → 按钮管理 → 添加按钮 → 添加内置操作」中可直接添加。
4. 添加入口后，必须同时出现在：
   - 菜单栏「快捷操作」子菜单
   - 手机面板「快捷操作」区
5. 新增 `FeatureModule` 时，模块自己的菜单必须保留一个直接「打开」项，并配全局或菜单快捷键（如果该功能需要频繁使用）。
6. 提测/提交前必须验证：从「内置操作」添加后，点一下确实能打开目标功能；不能只验证配置写入。

### 不需要重复添加的情况

- 纯后台能力、纯数据迁移、内部重构：不需要新增打开按钮，但必须在提交说明中写明「无用户可见入口」。
- 一个已有打开按钮的功能内部新增子能力：沿用该功能的打开入口，不要求为每个子按钮单独建入口。

### 反例

- 只加「设置」页入口，没有快捷打开按钮 → 不合格。
- 只写在 README / 菜单二级深处 → 不合格。
- 内置操作能添加，但点了没反应 → 不合格。

## R1. 需求统一用 OpenSpec 管理

任何需求在动手前，必须先在 `openspec/changes/` 下建立对应变更；不允许只改代码、README 或配置而不留 OpenSpec 记录。

### 强制清单

1. 变更目录使用 `openspec/changes/<change-id>/`，`change-id` 用动词开头的英文短横线命名，例如 `add-readme-feature-screenshots`。
2. 每个变更至少包含 `proposal.md`，写明 Why、What Changes、Capabilities、Impact 与非目标。
3. 涉及实现方案时写 `design.md`；涉及多步执行时写 `tasks.md`，任务要可勾选。
4. 涉及能力行为变化时，在 `specs/<capability>/spec.md` 写 delta；归档后同步到 `openspec/specs/<capability>/spec.md`。
5. 交付完成后归档到 `openspec/changes/archive/YYYY-MM-DD-<change-id>/`，不能长期留在活动变更目录。
6. 提交说明必须引用 `change-id`；无用户可见入口时按 R0 写明。
7. `README`、`Docs/archive` 的需求记录必须能反向链接到对应 OpenSpec 变更。

### 不需要建变更的情况

- 纯错别字、纯格式化、纯依赖升级且不改变行为和文档结构：可以不建变更，但提交说明要写明「无行为变化」。
- 只要改变功能、接口、权限、用户可见结果、文档结构或截图资产范围，就必须建 OpenSpec 变更。

### 反例

- 需求直接改代码，事后才补 OpenSpec → 不合格。
- 只建 `proposal.md`，没有能力 delta 就归档 → 不合格。
- 归档后没有同步 `openspec/specs/` → 不合格。

## R2. 本机固定签名，禁止 ad-hoc 重置系统授权

本机开发和日常安装必须固定使用同一个代码签名身份，避免辅助功能、输入监控、屏幕录制和自动化授权反复失效。

### 唯一固定身份

- 名称：`MacAppControlDeck Self-Signed`
- SHA-1：`145AEA72352C419CCCD76D6536BC70E14B2E134F`（以钥匙串中当前证书为准；证书被重建/重信任后指纹会变化，需同步更新本节与规格）
- Bundle ID：`com.zhaojian.MacAppControlDeck`
- 自签名身份不加 hardened runtime；Apple Development 身份才使用 `--options runtime`

### 强制清单

1. 本机构建统一执行 `./Build/build.sh`，禁止手工 `codesign --sign -` 或手工 ad-hoc 重签后再安装。
2. `Build/build.sh` 和 `Build/package-release.sh` 必须通过 `Build/signing.sh` 的 `deck_sign_app` 签名，不得各自维护一套签名分支。
3. 签名后必须校验 designated requirement：
   - 稳定：`identifier "com.zhaojian.MacAppControlDeck" and certificate root = H"145aea72352c419cccd76d6536bc70e14b2e134f"`
   - 不稳定：只有 `cdhash H"..."`
4. 证书缺失时必须失败并提示 `./Build/setup-signing.sh`，禁止静默降级为 ad-hoc。
5. 本机日常使用的 `/Applications/MacAppControlDeck.app` 不得安装 ad-hoc 包；release 包只有显式 `DECK_ALLOW_ADHOC=1` 才允许 ad-hoc，并必须在说明中写明该包会重置 TCC 授权。
6. 禁止修改 Bundle ID、固定签名证书、自签名签名的 runtime 标志。任何一项变化都会让已有 TCC 授权失配。
7. 提测前必须执行：
   - `./Build/verify-signing.sh BuildOutput/MacAppControlDeck.app`
   - 覆盖安装后再执行 `./Build/verify-signing.sh /Applications/MacAppControlDeck.app`
8. 系统设置里出现重复条目时，只删除旧条目后重新添加当前 App；不得用 `tccutil reset` 批量清空用户其他权限。
9. 任何签名、打包或权限流程的变更，必须新建 OpenSpec 变更并在归档时同步 `openspec/specs/stable-code-signing/spec.md`。
10. CI（GitHub Actions）发布与自动升级包必须使用同一固定身份：证书只允许以加密 Secret 注入临时钥匙串，构建后仍须断言 DR 含 `certificate root = H"145aea72…"`；证书重建后同步更新 Secret，禁止用新证书签更新包。

### TCC 授权范围

以下授权都按签名身份匹配，不按 Bundle ID 无条件继承：

- 辅助功能：跨桌面激活、Event Tap 等
- 输入监控：桌宠/快捷键读取物理按键
- 屏幕录制：截图、录屏
- 自动化：通过 System Events 切换桌面

### 反例

- 为了省事用 `codesign --sign -` 打本机包 → 不合格。
- 发布脚本继续固定 ad-hoc，导致每次升级都重新授权 → 不合格。
- 构建日志没有输出实际签名身份，也没有检查 DR → 不合格。
- 签名失败后自动退回 ad-hoc 并继续构建 → 不合格。

## R3. 回归测试不再重复验证「打开应用」

「打开应用」的启动、激活与跨桌面流水线已经稳定。日常回归和提测**不再要求**验证该功能，避免每次改动都重复点按钮、跑真实应用。

### 默认跳过

- 不手动点击应用按钮，不验证启动、切前台、跨桌面切换
- 不因为新增 UI、面板、天气等无关功能而重复跑这类手工用例
- 自动化测试里的激活用例可以保留，但默认跳过；需要时用 `DECK_RUN_ACTIVATION_E2E=1 swift test` 显式启用

### 仍需验证的例外

1. 改动涉及 `Control/AppControl.swift`、`Control/QuickActionRunner.swift`、`DeckState.perform`、`/api/activate` 或按钮执行队列
2. 改动涉及辅助功能、自动化、签名身份或 Bundle ID
3. 改动涉及应用按钮的数据结构、排序或删除
4. 用户明确要求验证

### 提交说明

- 未验证「打开应用」时不需要写「未测试」
- 属于上述例外时，必须在提交说明里写清验证结果

### 反例

- 改了 `AppControl` 却以「打开应用已稳定」为由不测 → 不合格。
- 每次加一个天气字段都重跑打开应用的手工用例 → 浪费时间。

## R4. 自动化测试只跑受影响功能，不做全量回归

自动化测试（`swift test`）按改动范围选择用例，不要求每次改动都跑整套；全量只在明确需要时跑。

### 强制清单

1. 按改动定位最小测试集，用 `swift test --filter <TestClass>[/<testName>]` 精确执行，例如：
   - 改面板 HTML/CSS/JS → `--filter PanelLayoutTests`（必要时加 `APIRouterTests`）
   - 改桌宠渲染/状态机 → `--filter Pet`
   - 改配对/路由 → `--filter APIRouterTests` 或 `PairingManagerTests`
   - 改激活流水线 → 见 R3 例外
2. 提交说明里写清「跑了哪些用例、结果如何」；不确定该跑哪些时，按最近一次相关改动的测试范围取值。
3. 只有在以下情况才跑全量 `swift test`：
   - 改动跨多个模块或动了 `Package.swift` / 依赖 / 构建脚本
   - 准备发版（release / tag）前
   - 用户明确要求全量
4. 发现与本改动无关的既有失败，记录现象与文件行号，不要顺手改成「全绿」；与本改动相关的失败必须修掉。

### 提交说明

- 写明实际执行的过滤条件与结果，例如「`swift test --filter PanelLayoutTests`：4 项全绿」。
- 跑了全量时说明原因。

### 反例

- 只改了一个面板字号，却先跑 142 项全量测试再开始改 → 浪费时间。
- 改了 `PanelHTML` 只跑 `swift test` 里的 `CalendarStoreTests`，完全没碰受影响用例 → 不合格。
- 为了「全绿」把无关的既有失败用例改成跳过 → 掩盖问题。
