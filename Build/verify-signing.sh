#!/bin/zsh
# 校验 App 是否使用稳定签名身份，而不是 ad-hoc / 纯 cdhash。
# 用法:
#   ./Build/verify-signing.sh
#   ./Build/verify-signing.sh BuildOutput/MacAppControlDeck.app
#   ./Build/verify-signing.sh /Applications/MacAppControlDeck.app
set -euo pipefail

cd "$(dirname "$0")/.."
APP="${1:-/Applications/MacAppControlDeck.app}"

if [[ ! -d "$APP" ]]; then
  echo "错误：App 不存在：$APP"
  exit 2
fi

echo "==> 校验签名完整性"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 签名摘要"
codesign -dv --verbose=4 "$APP" 2>&1 \
  | grep -E 'Identifier=|Authority=|TeamIdentifier=|Signature=|CDHash=|Signed Time=' || true

echo "==> designated requirement"
DR="$(codesign -d --requirements - "$APP" 2>&1 || true)"
print -r -- "$DR"

if print -r -- "$DR" | grep -q 'cdhash'; then
  echo "结果：不稳定签名（ad-hoc，DR 只有 cdhash）"
  echo "影响：每次重建/重装都会重新申请辅助功能、输入监控、屏幕录制和自动化授权。"
  exit 1
fi

if ! print -r -- "$DR" | grep -Eq 'certificate root|certificate leaf|anchor apple'; then
  echo "结果：未识别的签名身份"
  exit 1
fi

echo "结果：稳定签名（TCC 授权可跨重建保持匹配）"
