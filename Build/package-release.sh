#!/bin/zsh
# 按架构打包可分发版本：./Build/package-release.sh arm64|x86_64|universal
#
# universal 是自动升级用的单包：Sparkle 的 appcast 无法按 CPU 架构挑条目，
# 所以只发布一条 lipo 合并后的 App，避免把错误架构的包下给用户。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="MacAppControlDeck"
ARCH="${1:-}"
case "$ARCH" in
  arm64)  SCRATCH="$ROOT/.build-arm64" ;;
  x86_64) SCRATCH="$ROOT/.build-x86_64" ;;
  universal) SCRATCH="$ROOT/.build-arm64" ;;
  *) echo "用法: $0 arm64|x86_64|universal"; exit 2 ;;
esac

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Build/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Build/Info.plist")
OUT="$ROOT/BuildOutput/release/$ARCH"
APP="$OUT/$APP_NAME.app"
ZIP="$OUT/$APP_NAME-$VERSION-$ARCH.zip"
INSTALLER_ZIP="$OUT/$APP_NAME-$VERSION-$ARCH-installer.zip"
DMG="$OUT/$APP_NAME-$VERSION-$ARCH.dmg"
DMG_SRC="$OUT/dmg"
source "$ROOT/Build/signing.sh"

# 组装一个 .app：$1=目标 App 路径 $2=bin 目录 $3=图标工作目录
assemble_app() {
  local app="$1" bin_dir="$2" icon_dir="$3"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin_dir/$APP_NAME" "$app/Contents/MacOS/$APP_NAME"
  cp "$bin_dir/KeySender" "$app/Contents/MacOS/KeySender"
  cp "$ROOT/Build/Info.plist" "$app/Contents/Info.plist"
  cp "$ROOT/LICENSE" "$app/Contents/Resources/LICENSE"
  cp "$ROOT/THIRD_PARTY_NOTICES.md" "$app/Contents/Resources/THIRD_PARTY_NOTICES.md"
  cp -R "$ROOT/Resources/Licenses" "$app/Contents/Resources/Licenses"

  echo "==> 复制 SwiftPM 资源 bundle"
  find "$bin_dir" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$app/Contents/Resources/" \;

  echo "==> 嵌入 Sparkle.framework（自动升级）"
  deck_embed_sparkle "$app" "$bin_dir"

  echo "==> 生成图标"
  local iconset="$icon_dir/AppIcon.iconset"
  rm -rf "$iconset"
  swift "$ROOT/Build/make-icon.swift" "$iconset" >/dev/null
  iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
  rm -rf "$iconset"
}

build_arch() {
  local arch="$1" scratch="$2"
  echo "==> 清理 $arch 构建缓存（避免已删除资源残留在 SwiftPM bundle）"
  swift package clean --scratch-path "$scratch" >/dev/null
  echo "==> 获取 $arch 构建产物"
  swift build -c release --arch "$arch" --scratch-path "$scratch"
  swift build -c release --arch "$arch" --scratch-path "$scratch" --show-bin-path
}

rm -rf "$OUT"
mkdir -p "$OUT"

if [[ "$ARCH" == "universal" ]]; then
  BIN_ARM=$(build_arch arm64 "$ROOT/.build-arm64" | tail -1)
  BIN_X86=$(build_arch x86_64 "$ROOT/.build-x86_64" | tail -1)

  echo "==> 组装 universal $APP"
  assemble_app "$APP" "$BIN_ARM" "$OUT"

  echo "==> lipo 合并主程序与 KeySender"
  lipo -create "$BIN_ARM/$APP_NAME" "$BIN_X86/$APP_NAME" -output "$APP/Contents/MacOS/$APP_NAME.tmp" \
    && mv "$APP/Contents/MacOS/$APP_NAME.tmp" "$APP/Contents/MacOS/$APP_NAME"
  lipo -create "$BIN_ARM/KeySender" "$BIN_X86/KeySender" -output "$APP/Contents/MacOS/KeySender.tmp" \
    && mv "$APP/Contents/MacOS/KeySender.tmp" "$APP/Contents/MacOS/KeySender"

  echo "==> 校验架构"
  ACTUAL=$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")
  if [[ "$ACTUAL" != *"arm64"* || "$ACTUAL" != *"x86_64"* ]]; then
    echo "架构不符：期望 arm64 + x86_64，实际 $ACTUAL"; exit 3
  fi
  echo "主程序架构: $ACTUAL"
else
  BIN_DIR=$(build_arch "$ARCH" "$SCRATCH" | tail -1)
  echo "==> 组装 $APP"
  assemble_app "$APP" "$BIN_DIR" "$OUT"

  echo "==> 校验架构"
  ACTUAL=$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")
  if [[ "$ACTUAL" != "$ARCH" ]]; then
    echo "架构不符：期望 $ARCH，实际 $ACTUAL"; exit 3
  fi
  echo "主程序架构: $ACTUAL"
fi

echo "==> 签名（默认固定自签名；ad-hoc 需显式 DECK_ALLOW_ADHOC=1）"
deck_sign_app "$APP"
deck_print_signature_summary "$APP"

echo "==> 组装人用的安装包目录（App + 安装脚本 + 说明）"
BUNDLE_DIR="$OUT/$APP_NAME-$VERSION-$ARCH"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"
cp -R "$APP" "$BUNDLE_DIR/"
cp "$ROOT/Build/install-friendly.command" "$BUNDLE_DIR/安装 MacAppControlDeck.command"
cp "$ROOT/Build/install-readme.txt" "$BUNDLE_DIR/安装说明.txt"
chmod +x "$BUNDLE_DIR/安装 MacAppControlDeck.command"

echo "==> 生成更新用 ZIP（App 位于压缩包根目录，供 Sparkle 解压替换）"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> 生成人用的聊天传输 ZIP（含安装脚本）"
rm -f "$INSTALLER_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_DIR" "$INSTALLER_ZIP"

echo "==> 生成 DMG"
mkdir -p "$DMG_SRC"
cp -R "$BUNDLE_DIR/"* "$DMG_SRC/"
ln -s /Applications "$DMG_SRC/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME $VERSION $ARCH" \
  -srcfolder "$DMG_SRC" -ov -format UDZO "$DMG"
rm -rf "$DMG_SRC" "$BUNDLE_DIR"

echo "==> 生成校验和"
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" "$(basename "$INSTALLER_ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt)

echo "==> 完成: $OUT"
ls -lh "$ZIP" "$INSTALLER_ZIP" "$DMG" "$OUT/SHA256SUMS.txt"
echo "VERSION=$VERSION BUILD=$BUILD_NUMBER"
