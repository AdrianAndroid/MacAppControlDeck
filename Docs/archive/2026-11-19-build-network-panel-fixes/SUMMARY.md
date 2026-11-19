# 总结：构建补齐、局域网地址与面板配对体验修复（2026-11-19）

- 对应版本：0.1.0（构建后安装至 `/Applications/MacAppControlDeck.app`）
- 涉及文件：`Build/`（新增）、`Sources/.../Server/LANAddress.swift`、`Sources/.../Server/APIRouter.swift`、`Sources/.../Panel/PanelHTML.swift`、`README.md`
- 状态：已修复并真机验证（iPhone 可正常配对使用）

## 一、问题与根因

### 1. 仓库缺少构建资产，无法按文档打包

- 现象：`README` 要求执行 `./Build/setup-signing.sh`、`./Build/build.sh`，但仓库中不存在 `Build/` 目录（`git ls-files` 无任何 `.sh`/`Info.plist`/`.icns`）。
- 根因：`.gitignore` 里的 `build/` 规则在大小写不敏感的文件系统上同时匹配了源码目录 `Build/`，构建脚本从未入库；同时 `build/`（小写）与 `Build/`（大写）在 macOS 上是**同一个目录**，构建产物会直接落进源码目录。
- 修复：
  - 补齐 `Build/Info.plist`、`Build/build.sh`、`Build/make-icon.swift`、`Build/setup-signing.sh`
  - 产出目录改为 `BuildOutput/`（加入 `.gitignore`），并在 `.gitignore` 中反选 `!Build/` 以允许脚本入库
  - `build.sh` 顺序：`swift build -c release` → 组装 `.app` → 生成 icns → **先签内嵌 `KeySender` 再签整包** → `codesign --verify --deep --strict`

### 2. 签名校验失败（"does not satisfy its designated Requirement"）

- 现象：签名后 `codesign --verify` 报 DR 不满足，`spctl` 报 "a required plist file or resource is malformed"。
- 根因：`Info.plist` 中存在标签错配（`</string>` 被写成 `</key>`），plist 无法解析，Bundle 元数据缺失，签名 DR 与 Gatekeeper 校验必然失败。
- 修复：修正 plist，`plutil -lint` 通过后重新签名；签名身份使用 `MacAppControlDeck Self-Signed`（已在登录钥匙串建立代码签名信任），重建不丢 TCC 授权。

### 3. 面板地址不可用、正确 IP 被 403

- 现象：面板显示 `http://169.254.126.154:47615/panel/`，手机访问不到；即使手输 `192.168.18.159` 也被拒绝。
- 根因：
  - `LANAddress.localIPv4()` 只优先 `en0`。这台 Mac 的**有线口是 en0（未插网线，只有 169.254 链路本地地址）**，Wi-Fi 是 **en1（192.168.18.159）**；函数却对 en0 无条件 `break`，导致始终返回不可用的链路本地地址。
  - `APIRouter` 的 Host 白名单只比对 `LANAddress.localIPv4()` 的单个值 + 回环，因此正确的局域网 IP 也会被判 403。
- 修复：
  - 重写地址枚举：收集所有 `en*`/`bridge*` 的活动接口，**链路本地地址降到最低优先级**，按 en0 → en1 → 其他排序；新增 `localIPv4s()` 供鉴权使用。
  - 新增 `HostPolicy`：接受本机所有局域网地址、私有/链路本地 IP 字面量、`localhost`、`*.local`；公网域名继续 403（防 DNS rebinding）。
- 验证：`curl -H "Host: 192.168.18.159:47615" http://192.168.18.159:47615/api/health` → 200；`Host: evil.example.com` → 403；`Host: xxx.local` → 200。

### 4. Android 浏览器连不上（服务端零响应）

- 现象：Pixel（192.168.18.154）能建立 TCP 连接，但页面一直转圈直至超时；同一 Wi-Fi 下 iPhone 正常。
- 证据（`log show --predicate 'process == "MacAppControlDeck"'`，NWConnection 统计）：

  ```
  C66 192.168.18.159:47615<->IPv4#02325a17:44010
  Duration: 30.016s
  bytes in/out: 1797/0
  ```

  1797 字节是 TLS ClientHello 的量级，服务端 0 字节响应——浏览器把 `http://` 升级成了 HTTPS，而本服务只支持明文 HTTP，解析器一直等待 `\r\n\r\n`。
- 结论：服务端无缺陷；iPhone Safari 不对裸 IP 做 HTTPS 升级，Android Chrome/部分国产浏览器默认「HTTPS 优先」。
- 处理（设备侧）：完整输入 `http://IP:PORT/panel/`；关闭 Chrome「始终使用安全连接」（`chrome://flags/#https-upgrades` 设为 Disabled）；关闭 VPN/私人 DNS；或改用 Firefox。

### 5. 配对成功却不跳转（按钮数为 0 时退回配对页）

- 现象：手机输入配对码后提示「配对成功」，但界面仍停留在配对页，看不到按钮面板。
- 根因：`PanelHTML.render()` 中的显示判定为 `token && buttons.length`。`devices.json` 已有该设备 token，但 `buttons.json` 不存在（`/api/buttons` 返回 `{"buttons":[]}`），于是主界面被隐藏、配对页重新显示。
- 修复：已配对（存在 token）时**始终进入主界面**；按钮为空时渲染空状态提示「还没有按钮 / 请在 Mac 端『添加应用按钮』或『添加快捷操作』」，并隐藏快捷操作区。
- 验证：`/api/buttons` 返回空数组时，面板仍展示主界面与空状态；Mac 端添加按钮后，面板 5 秒轮询自动刷新，无需重新配对。

## 二、验证清单

| 项 | 结果 |
|---|---|
| `swift build -c release` | 通过（存在既有 warning：`activate(from:)` 上的无效 `await`） |
| `codesign --verify --deep --strict` | `valid on disk` / `satisfies its Designated Requirement` |
| 进程与监听 | PID 正常运行，`tcp46 *:47615 LISTEN` |
| 本机 LAN IP 访问 | `/api/health` 200，`/panel/` 200 |
| Host 白名单 | 私网 IP/.local 放行；公网域名 403 |
| 真机 | iPhone 配对并进入面板；Pixel 转为明文 HTTP 后可用 |

## 三、仍待处理

1. 同名设备互踢：`ConfigStore.addDevice` 会按 `name` 覆盖旧记录，两台默认名为 `iPhone` 的设备会互相注销。
2. 配对接口缺少频率限制（规格要求每设备每分钟 5 次）。
3. 服务端对非 HTTP 数据（TLS 握手）没有读超时与显式识别，连接会一直挂到客户端超时；建议识别后立即关闭并记录。
4. 二维码未实现（`specs/host-app-shell` 有要求）。
5. 面板快捷区固定 3 行，与规格「1–4 行自适应、横屏 6×2」不一致，需同步规格或代码。
