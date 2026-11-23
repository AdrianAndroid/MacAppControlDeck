# 任务：更新签名身份指纹与归档记录

## 1. 更新指纹

- [x] 1.1 `Build/signing.sh` 常量改为 `145AEA72…`
- [x] 1.2 `AGENTS.md` R2 与 `README.md` 说明改为「名称固定、指纹以当前证书为准」
- [x] 1.3 `openspec/specs/stable-code-signing/spec.md` 同步新指纹与重建说明

## 2. 归档记录

- [x] 2.1 新增 `Docs/archive/2026-11-23-friendly-install-and-panel-clock/SUMMARY.md`
- [x] 2.2 README 归档区加入该记录并链接各 OpenSpec 变更
- [x] 2.3 `./Build/verify-signing.sh /Applications/MacAppControlDeck.app` 复核通过
