#!/bin/zsh
# 按架构打包可分发版本：./Build/package-release.sh arm64|x86_64
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="MacAppControlDeck"
ARCH="${1:-}"
case "$ARCH" in
  arm64)  SCRATCH="$ROOT/.build-arm64" ;;
  x86_64) SCRATCH="$ROOT/.build-x86_64" ;;
  *) echo "用法: $0 arm64|x86_64"; exit 2 ;;
esac

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Build/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Build/Info.plist")
OUT="$ROOT/BuildOutput/release/$ARCH"
APP="$OUT/$APP_NAME.app"
ZIP="$OUT/$APP_NAME-$VERSION-$ARCH.zip"
DMG="$OUT/$APP_NAME-$VERSION-$ARCH.dmg"
DMG_SRC="$OUT/dmg"

echo "==> 获取 $ARCH 构建产物"
swift build -c release --arch "$ARCH" --scratch-path "$SCRATCH"
BIN_DIR=$(swift build -c release --arch "$ARCH" --scratch-path "$SCRATCH" --show-bin-path)

echo "==> 组装 $APP"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$BIN_DIR/KeySender" "$APP/Contents/MacOS/KeySender"
cp "$ROOT/Build/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp -R "$ROOT/Resources/Licenses" "$APP/Contents/Resources/Licenses"

echo "==> 复制 SwiftPM 资源 bundle"
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

echo "==> 生成图标"
ICONSET="$OUT/AppIcon.iconset"
swift "$ROOT/Build/make-icon.swift" "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "==> 签名（未公证，分发用 ad-hoc）"
codesign --force --sign - "$APP/Contents/MacOS/KeySender"
codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 校验架构"
ACTUAL=$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")
if [[ "$ACTUAL" != "$ARCH" ]]; then
  echo "架构不符：期望 $ARCH，实际 $ACTUAL"; exit 3
fi
echo "主程序架构: $ACTUAL"

echo "==> 生成 ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> 生成 DMG"
mkdir -p "$DMG_SRC"
cp -R "$APP" "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME $VERSION $ARCH" \
  -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG"
rm -rf "$DMG_SRC"

echo "==> 生成校验和"
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt)

echo "==> 完成: $OUT"
ls -lh "$ZIP" "$DMG" "$OUT/SHA256SUMS.txt"
echo "VERSION=$VERSION BUILD=$BUILD_NUMBER"
