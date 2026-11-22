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

echo "==> 复制 SwiftPM 资源 bundle"
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

echo "==> 生成图标"
ICONSET="$BUILD_ROOT/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$ROOT/Build/make-icon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> 签名"
source "$ROOT/Build/signing.sh"
deck_sign_app "$APP"
deck_print_signature_summary "$APP"
echo "==> 完成: $APP"
