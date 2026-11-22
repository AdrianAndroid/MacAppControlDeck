# desktop-pet Delta

## MODIFIED Requirements

### Requirement: 无桌面分层场景

系统 SHALL 以 v6 的 `shadow / keyboard / keycap / mouse / torso / neck / head / earL / earR / armL / armR / tail1 / tail2 / iris_l / iris_r / pupil_l / pupil_r` 十七层合成桌宠，场景中不得出现木桌、桌面纹理、墙或矩形底板；猫身下缘 SHALL 由键盘层遮挡，不得出现横向截断硬边或悬空。

#### Scenario: 透明待机

- **WHEN** 桌宠以任意档位打开
- **THEN** 窗口中只出现黑猫、白色键盘、白色鼠标与柔和接触阴影
- **AND** 桌线、木纹与桌面四边完全透明，能看见下层壁纸

#### Scenario: 三档尺寸

- **WHEN** 用户切换小 / 中 / 大
- **THEN** 键盘底边、鼠标与阴影完整可见，猫身下缘不出现悬空缝隙
- **AND** 不出现硬切边、灰晕或矩形接缝

#### Scenario: 资产缺失

- **WHEN** `Resources/v6` 缺任一必需图层或 manifest 校验失败
- **THEN** 整体回退 v4 渲染，不混搭半套图层
- **AND** 桌宠仍可打开，不崩溃

### Requirement: 光栅分层渲染与回退（v6 → v4 → 矢量）

系统 SHALL 为午夜黑猫提供 720×960 设计基准的透明分层栅格渲染，优先使用 v6 全身骨骼：场景只包含黑猫、白色键盘、白色鼠标、柔和接触阴影与键帽，不得包含木桌、桌面纹理、米色墙面或矩形底板。渲染 SHALL 按 v6 的十七层顺序合成。v6 资产缺失或校验失败时 SHALL 回退 v4，再回退矢量渲染，不得崩溃、不得混搭半套图层；不得加载任何未定义的旧版图层。

#### Scenario: 黑猫透明待机

- **WHEN** 用户以中号打开桌宠
- **THEN** 桌面只显示黑猫、白键盘、白鼠标与柔和接触阴影，背景完全透明
- **AND** 不出现桌线、木纹、米色墙、矩形底或白边

#### Scenario: 三档尺寸不裁切

- **WHEN** 用户切换小/中/大任意一档
- **THEN** 耳尖、后腿、脚掌、尾巴尖、键盘底边和鼠标都完整可见
- **AND** 切换以底部中心为锚点，不跳位

#### Scenario: 资产不可用

- **WHEN** v6 的 `manifest.json` 缺失、PNG 尺寸不符或 alpha 为空
- **THEN** 整体回退 v4，再回退矢量皮肤
- **AND** 桌宠仍可打开，不崩溃

### Requirement: v4 活动时钟与生命周期

系统 SHALL 在输入活动期以 30fps 驱动光栅渲染（v6 优先，v4 回退），静止期降到空闲帧率；窗口隐藏、锁屏、休眠或录制隐藏时 SHALL 停止 30fps 时钟。光栅渲染不得增加新的系统权限，键盘仍只读 keyCode。

#### Scenario: 活动爆发

- **WHEN** 用户按键或移动鼠标
- **THEN** 动画在 0.9s 内以 30fps 运行，键帽弹出与头部跟随平滑
- **AND** 0.9s 后无新输入直接降到空闲 2fps

#### Scenario: 隐藏桌宠

- **WHEN** 用户关闭或隐藏桌宠
- **THEN** 30fps 时钟、输入监听与窗口资源全部释放
- **AND** 后台无空转定时器

#### Scenario: 安全输入

- **WHEN** 系统处于 Secure Input、锁屏或休眠
- **THEN** 视线与头部目标冻结并回正，键帽停止生成
- **AND** 恢复后继续，不补发暂停期间的键帽

#### Scenario: 隐私

- **WHEN** 用户任意输入
- **THEN** 系统只读取 keyCode 映射键位字符
- **AND** 不读取输入文本、不写日志、不联网
