#!/bin/zsh
# 为 Sparkle 生成 appcast.xml：./Build/make-appcast.sh <目录> <下载前缀>
#
# 目录里放更新的 ZIP（App 位于压缩包根目录，文件名含版本号），
# 脚本用 Sparkle 官方 generate_appcast 自动签名（EdDSA 私钥在登录钥匙串）。
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
DIR="${1:-}"
PREFIX="${2:-}"
if [[ -z "$DIR" || -z "$PREFIX" ]]; then
  echo "用法: $0 <ZIP 目录> <下载 URL 前缀>"
  exit 2
fi

BIN_DIR=$(swift build -c release --show-bin-path 2>/dev/null || true)
TOOLS="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
if [[ ! -x "$TOOLS/generate_appcast" ]]; then
  echo "错误：找不到 Sparkle 工具：$TOOLS/generate_appcast"
  echo "请先执行 swift package resolve 下载 Sparkle 二进制产物。"
  exit 3
fi

# CI 里私钥来自 Secret（DECK_ED_KEY_FILE），本机则用登录钥匙串里的密钥。
ed_key_args=()
if [[ -n "${DECK_ED_KEY_FILE:-}" ]]; then
  ed_key_args=(--ed-key-file "$DECK_ED_KEY_FILE")
fi

# generate_appcast 要求目录里每种 bundle version 只能有一个归档；产物目录同时
# 放着更新 ZIP、installer ZIP 和 DMG（同版本），会被判为 "Duplicate updates"。
# 因此建一个只放更新 ZIP 的暂存目录来生成，再把结果拷回产物目录。
UPDATE_ZIP=$(find "$DIR" -maxdepth 1 -name "*-universal.zip" ! -name "*-installer.zip" -print -quit)
if [[ -z "$UPDATE_ZIP" ]]; then
  echo "错误：在 $DIR 找不到更新用 ZIP（*-universal.zip）"
  exit 4
fi

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
cp "$UPDATE_ZIP" "$STAGING/"

echo "==> 生成 appcast.xml（仅用 $(basename "$UPDATE_ZIP")，下载前缀 $PREFIX）"
"$TOOLS/generate_appcast" "${ed_key_args[@]}" --download-url-prefix "$PREFIX" \
  -o "$STAGING/appcast.xml" "$STAGING"
cp "$STAGING/appcast.xml" "$DIR/appcast.xml"
# generate_appcast 可能生成增量更新 / old_updates 等附属文件，一并带回
for extra in "$STAGING"/*; do
  base=$(basename "$extra")
  [[ "$base" == "appcast.xml" || "$base" == "$(basename "$UPDATE_ZIP")" ]] && continue
  [[ -e "$DIR/$base" ]] && continue
  cp -R "$extra" "$DIR/"
done

echo "==> 生成 SHA256SUMS.txt"
(cd "$DIR" && setopt local_options null_glob && shasum -a 256 -- *.zip *.dmg appcast.xml > SHA256SUMS.txt)

echo "==> 完成: $DIR/appcast.xml"
