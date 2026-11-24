#!/bin/zsh
# 固定签名身份与 TCC 稳定性工具。被 build.sh / package-release.sh source 使用。
#
# 规则：
# - 本机默认只使用 MacAppControlDeck Self-Signed。
# - 找不到证书时直接失败，不静默降级为 ad-hoc。
# - 只有显式 DECK_ALLOW_ADHOC=1 才允许 ad-hoc，并提示该包会重置 TCC 授权。
# - 签名后必须校验 designated requirement 不是纯 cdhash。

set -euo pipefail

DECK_CANONICAL_SIGN_IDENTITY="MacAppControlDeck Self-Signed"
DECK_CANONICAL_SIGN_SHA1="145AEA72352C419CCCD76D6536BC70E14B2E134F"

deck_signing_identity() {
  if [[ -n "${DECK_SIGN_IDENTITY:-}" ]]; then
    print -r -- "$DECK_SIGN_IDENTITY"
  else
    print -r -- "$DECK_CANONICAL_SIGN_IDENTITY"
  fi
}

deck_identity_exists() {
  local identity="$1"
  security find-identity -v -p codesigning 2>/dev/null \
    | grep -Fq "\"$identity\""
}

deck_require_identity() {
  local identity
  identity="$(deck_signing_identity)"

  if ! deck_identity_exists "$identity"; then
    print -u2 -- "错误：找不到稳定签名身份：$identity"
    print -u2 -- "本机构建禁止自动降级为 ad-hoc，否则 TCC 授权会再次失效。"
    print -u2 -- "请先执行：./Build/setup-signing.sh"
    print -u2 -- "或在钥匙串中确认该证书存在并允许 codesign 使用。"
    return 1
  fi
}

deck_assert_stable_signature() {
  local app="$1"
  local dr

  if [[ ! -d "$app" ]]; then
    print -u2 -- "错误：App 不存在：$app"
    return 1
  fi

  dr="$(codesign -d --requirements - "$app" 2>&1 || true)"

  if print -r -- "$dr" | grep -q 'cdhash'; then
    print -u2 -- "错误：$app 的 designated requirement 仍是纯 cdhash（ad-hoc）。"
    print -u2 -- "$dr"
    print -u2 -- "这会导致每次重建/重装都重新申请 TCC 授权。"
    return 1
  fi

  if ! print -r -- "$dr" | grep -Eq 'certificate root|certificate leaf|anchor apple'; then
    print -u2 -- "错误：$app 的 designated requirement 不是稳定证书身份。"
    print -u2 -- "$dr"
    return 1
  fi

  print -r -- "  designated requirement 校验通过："
  print -r -- "$dr" | sed -n 's/^designated => /    /p'
}

# ---- Sparkle（自动升级）框架嵌入与签名 ----
# SwiftPM 只把二进制 target 下载到 artifacts，不会组装进 .app，所以这里显式处理：
# 复制 framework → 补 rpath → 由内向外重签（XPC → Updater.app → framework → 外层 App）。

deck_sparkle_framework() {
  local bin_dir="$1"
  local artifacts
  artifacts="$(cd "$(dirname "$bin_dir")/.." && pwd)/artifacts/sparkle/Sparkle/Sparkle.xcframework"
  local framework="$artifacts/macos-arm64_x86_64/Sparkle.framework"
  if [[ ! -d "$framework" ]]; then
    print -u2 -- "错误：找不到 Sparkle.framework：$framework"
    print -u2 -- "请先执行 swift package resolve 下载 Sparkle 二进制产物。"
    return 1
  fi
  print -r -- "$framework"
}

deck_embed_sparkle() {
  local app="$1"
  local bin_dir="$2"
  local framework
  framework="$(deck_sparkle_framework "$bin_dir")" || return 1

  mkdir -p "$app/Contents/Frameworks"
  rm -rf "$app/Contents/Frameworks/Sparkle.framework"
  cp -R "$framework" "$app/Contents/Frameworks/"

  local executable="$app/Contents/MacOS/MacAppControlDeck"
  if ! otool -l "$executable" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath '@executable_path/../Frameworks' "$executable"
  fi
  print -r -- "==> 已嵌入 Sparkle.framework（$(du -sh "$app/Contents/Frameworks/Sparkle.framework" | cut -f1)）"
}

deck_sign_sparkle_nested() {
  local app="$1"
  local identity="$2"
  shift 2
  local -a flags=("$@")
  local framework="$app/Contents/Frameworks/Sparkle.framework"
  [[ -d "$framework" ]] || return 0

  local item
  for item in "$framework"/Versions/B/XPCServices/*.xpc; do
    [[ -e "$item" ]] || continue
    codesign "${flags[@]}" --sign "$identity" "$item"
  done
  if [[ -d "$framework/Versions/B/Updater.app" ]]; then
    codesign "${flags[@]}" --sign "$identity" "$framework/Versions/B/Updater.app"
  fi
  codesign "${flags[@]}" --sign "$identity" "$framework"
}

deck_sign_app() {
  local app="$1"
  local identity
  local -a sign_flags

  if [[ ! -d "$app" ]]; then
    print -u2 -- "错误：App 不存在：$app"
    return 1
  fi

  identity="$(deck_signing_identity)"

  if [[ "${DECK_ALLOW_ADHOC:-0}" == "1" && -z "${DECK_SIGN_IDENTITY:-}" ]]; then
    print -u2 -- "警告：DECK_ALLOW_ADHOC=1，正在使用 ad-hoc 签名。"
    print -u2 -- "警告：该包每次重建/重装都会重置辅助功能、输入监控、屏幕录制和自动化授权。"
    print -u2 -- "警告：不要把该包安装到本机日常使用的 /Applications。"
    codesign --force --sign - "$app/Contents/MacOS/KeySender"
    deck_sign_sparkle_nested "$app" - --force
    codesign --force --sign - "$app"
    codesign --verify --deep --strict --verbose=2 "$app"
    return 0
  fi

  deck_require_identity || return 1

  sign_flags=(--force)
  case "$identity" in
    "Apple Development"*)
      sign_flags+=(--options runtime)
      ;;
    *)
      # 自签名身份不加 hardened runtime，避免签名标志变化导致旧 TCC 授权失配。
      ;;
  esac

  print -- "==> 签名身份：$identity（flags: ${sign_flags[*]}）"
  codesign "${sign_flags[@]}" --sign "$identity" "$app/Contents/MacOS/KeySender"
  deck_sign_sparkle_nested "$app" "$identity" "${sign_flags[@]}"
  codesign "${sign_flags[@]}" --sign "$identity" "$app"
  codesign --verify --deep --strict --verbose=2 "$app"
  deck_assert_stable_signature "$app"
}

deck_print_signature_summary() {
  local app="$1"
  print -- "==> 签名摘要：$app"
  codesign -dv --verbose=4 "$app" 2>&1 \
    | grep -E 'Identifier=|Authority=|TeamIdentifier=|Signature=|CDHash=|Signed Time=' || true
}
