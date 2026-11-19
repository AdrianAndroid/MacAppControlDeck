#!/bin/zsh
# 构建 / 组装 .app / 生成图标 / 签名
# 用法: ./Build/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="MacAppControlDeck"
CONFIG="release"
BUILD_ROOT="$ROOT/BuildOutput"
APP="$BUILD_ROOT/$APP_NAME.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)

echo "==> 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$BIN_DIR/KeySender" "$APP/Contents/MacOS/KeySender"
cp "$ROOT/Build/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"

echo "==> 生成图标"
ICONSET="$BUILD_ROOT/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Build/make-icon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> 签名"
IDENTITY="${DECK_SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "MacAppControlDeck Self-Signed"; then
    IDENTITY="MacAppControlDeck Self-Signed"
  fi
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)
fi

if [[ -n "$IDENTITY" ]]; then
  # 先签内嵌 CLI 助手，再签整个包
  codesign --force --options runtime --sign "$IDENTITY" "$APP/Contents/MacOS/KeySender"
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
  echo "已使用签名身份：$IDENTITY"
else
  codesign --force --sign - "$APP/Contents/MacOS/KeySender"
  codesign --force --sign - "$APP"
  echo "警告：未找到稳定证书，已使用 ad-hoc 签名（重建后需重新授权辅助功能）。建议先执行 ./Build/setup-signing.sh"
fi

codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> 完成: $APP"
