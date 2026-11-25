# Tasks

- [x] 全量扫描 3340 个 git 对象：EdDSA 私钥 / seed / PEM 私钥 0 命中；确认个人路径与测试白名单常量的上下文
- [x] 核查发布包（ZIP / installer ZIP / DMG）内容与二进制内嵌路径，确认无个人文件数据
- [x] 核查 GitHub 仓库安全设置（secret scanning / push protection）、Secrets 名称、workflow 触发条件与 Release 资产
- [x] 核查本机私钥位置与权限、p12 / 临时文件残留，确认 git 工作区干净
- [x] `.gitignore` 增加凭据与个人数据忽略规则（确认不影响已跟踪文件）
- [x] `Build/publish-local.sh` 增加「私钥在仓库外且未被 git 跟踪」断言
- [x] `Docs/releases/local-publish.md` 新增 public 仓库本地数据边界章节（结论、证据表、操作范围、commit 邮箱提醒、自查命令）
- [x] 归档变更并同步 `local-release-publishing` 主规格
