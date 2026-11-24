#!/bin/zsh
# 本机一键发布 —— 这台 Mac 是 MacAppControlDeck 的正式发版机。
#
# 为什么需要它：CI 曾经是主发版路径，但受 runner 版本 / arm64 容量排队影响，
# 且本机私钥只存在于登录钥匙串，非交互读取会弹「允许访问钥匙串」授权框而卡死，
# 导致本机无法稳定复现发版。本脚本把凭据固化在本机、全流程非交互。
#
# 用法：
#   ./Build/publish-local.sh --verify-only       # 只自检凭据并验证本机可重签线上 appcast
#   ./Build/publish-local.sh --dry-run           # 构建 + 签名 + 校验，不推 tag 不发布
#   ./Build/publish-local.sh                    # 完整发布（发布前二次确认）
#   ./Build/publish-local.sh --yes              # 完整发布，跳过交互确认
#   ./Build/publish-local.sh --skip-build       # 复用已有产物（须与 Info.plist 版本一致）
#   ./Build/publish-local.sh --notes-file FILE  # 指定 Release 说明
#   ./Build/publish-local.sh --verify-download  # 发布后再下载 ZIP 做 SHA256 复核
#
# 私钥位置（不进仓库）：~/.config/macappcontroldeck/sparkle_ed_key
# 从钥匙串导出：./.build/artifacts/sparkle/Sparkle/bin/generate_keys -x <路径> && chmod 600 <路径>
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
REPO="AdrianAndroid/MacAppControlDeck"
APP_NAME="MacAppControlDeck"
OUT="$ROOT/BuildOutput/release/universal"
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
KEY_FILE="${DECK_ED_KEY_FILE:-$HOME/.config/macappcontroldeck/sparkle_ed_key}"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Build/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/Build/Info.plist")
PUBKEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$ROOT/Build/Info.plist")
FEED=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$ROOT/Build/Info.plist")
TAG="v$VERSION"
DL_PREFIX="https://github.com/$REPO/releases/download/$TAG/"
FEED_URL="https://github.com/$REPO/releases/latest/download/appcast.xml"
APP="$OUT/$APP_NAME.app"
UPDATE_ZIP="$OUT/$APP_NAME-$VERSION-universal.zip"

MODE="publish"
NOTES_FILE=""
YES=0
SKIP_BUILD=0
ALLOW_DIRTY=0
VERIFY_DOWNLOAD=0

die()  { print -u2 -- "错误：$*"; exit 1; }
info() { print -r -- "==> $*"; }
ok()   { print -r -- "    ✓ $*"; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify-only)      MODE="verify" ;;
    --dry-run)          MODE="dry" ;;
    --skip-build)       SKIP_BUILD=1 ;;
    --notes-file)       NOTES_FILE="${2:-}"; [[ -n "$NOTES_FILE" ]] || die "--notes-file 需要路径"; shift ;;
    --yes|-y)           YES=1 ;;
    --allow-dirty)      ALLOW_DIRTY=1 ;;
    --verify-download)  VERIFY_DOWNLOAD=1 ;;
    -h|--help)          usage ;;
    *) die "未知参数：$1（--help 查看用法）" ;;
  esac
  shift
done

# ---- 凭据自检：所有模式都跑，且不打印任何私钥内容 ----
check_credentials() {
  info "自检发版凭据（本机主发版机）"

  command -v gh >/dev/null 2>&1 || die "缺少 gh CLI"
  gh auth status >/dev/null 2>&1 || die "gh 未登录（gh auth login）"
  local repo
  repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
  [[ "$repo" == "$REPO" ]] || die "当前仓库不是 $REPO（实际 ${repo:-未知}）"
  ok "gh 已登录，仓库 $REPO"

  [[ -x "$SPARKLE_BIN/generate_appcast" && -x "$SPARKLE_BIN/sign_update" && -x "$SPARKLE_BIN/generate_keys" ]] \
    || die "Sparkle 工具缺失，先执行 swift package resolve"
  ok "Sparkle 工具就绪（generate_appcast / sign_update / generate_keys）"

  security find-identity -v -p codesigning 2>/dev/null \
    | grep -Fq '"MacAppControlDeck Self-Signed"' \
    || die "固定签名身份 MacAppControlDeck Self-Signed 缺失，执行 ./Build/setup-signing.sh"
  SIGN_SHA1=$(security find-certificate -c 'MacAppControlDeck Self-Signed' -Z 2>/dev/null \
    | awk '/SHA-1 hash:/{print $NF}' | head -1)
  [[ -n "$SIGN_SHA1" ]] || die "读不到固定证书 SHA-1"
  ok "签名身份 MacAppControlDeck Self-Signed ($SIGN_SHA1)"

  [[ -s "$KEY_FILE" ]] || die "找不到 EdDSA 私钥：$KEY_FILE（用 generate_keys -x 从钥匙串导出后 chmod 600）"
  local perm seed_len
  perm=$(stat -f '%Lp' "$KEY_FILE")
  [[ "$perm" == "600" ]] || die "私钥文件权限应为 600，当前 $perm（chmod 600 \"$KEY_FILE\"）"
  seed_len=$(base64 -D < "$KEY_FILE" 2>/dev/null | wc -c | tr -d ' ')
  [[ "$seed_len" == "32" ]] || die "私钥不是有效的 32 字节 Ed25519 种子（解码长度 $seed_len）"
  ok "EdDSA 私钥就绪（600 权限、32 字节种子，内容不打印）"

  local kc_pub
  kc_pub=$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null | tail -1 | tr -d '\r\n')
  [[ "$kc_pub" == "$PUBKEY" ]] \
    || die "钥匙串公钥与 Info.plist SUPublicEDKey 不一致（钥匙串=$kc_pub plist=$PUBKEY）；禁止轮换公钥，否则存量用户升级链断裂"
  ok "钥匙串公钥与 Info.plist SUPublicEDKey 一致（未轮换）"

  [[ "$FEED" == *"$REPO/releases/latest/download/appcast.xml"* ]] \
    || die "SUFeedURL 不指向本仓库：$FEED"
  ok "更新源指向 $FEED_URL"
}

# ---- 仓库状态自检：只有真正发版 / dry-run 才需要 ----
check_repo_state() {
  info "自检仓库状态"
  if [[ "$ALLOW_DIRTY" == 0 ]]; then
    [[ -z "$(git status --porcelain)" ]] || die "工作区有未提交改动（先提交，或 --allow-dirty）"
  fi
  local branch head remote
  branch=$(git rev-parse --abbrev-ref HEAD)
  [[ "$branch" == "main" ]] || die "请在 main 分支发版（当前 $branch）"
  git fetch origin main --quiet
  head=$(git rev-parse HEAD)
  remote=$(git rev-parse origin/main)
  [[ "$head" == "$remote" ]] || die "本地 HEAD 与 origin/main 不一致，先 pull / push"
  ok "main 与 origin/main 同步（$head）"

  if [[ "$MODE" == "publish" ]]; then
    if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
      die "本地 tag $TAG 已存在（避免重复发布）"
    fi
    if gh release view "$TAG" >/dev/null 2>&1; then
      die "远程 Release $TAG 已存在（本脚本不覆盖已有 Release）"
    fi
  fi
  ok "版本 $VERSION (build $BUILD_NUMBER) 可发布"
}

# ---- 产物校验 ----
verify_artifacts() {
  info "校验发布产物"
  [[ -d "$APP" ]] || die "找不到 App：$APP"
  [[ -s "$UPDATE_ZIP" ]] || die "找不到更新 ZIP：$UPDATE_ZIP"
  [[ -s "$OUT/appcast.xml" && -s "$OUT/SHA256SUMS.txt" ]] || die "appcast.xml / SHA256SUMS.txt 缺失"

  local app_version
  app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
  [[ "$app_version" == "$VERSION" ]] || die "产物版本 $app_version 与 Info.plist 的 $VERSION 不一致（--skip-build 不能跨版本复用）"

  local archs
  archs=$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")
  [[ "$archs" == *arm64* && "$archs" == *x86_64* ]] || die "不是 universal 包：$archs"
  ok "universal 架构：$archs"

  "$ROOT/Build/verify-signing.sh" "$APP" >/dev/null 2>&1 \
    || die "verify-signing.sh 失败（单独执行该文件查看细节）"
  local dr sha1_lower
  dr=$(codesign -d --requirements - "$APP" 2>&1)
  sha1_lower=$(print -r -- "$SIGN_SHA1" | tr 'A-Z' 'a-z')
  print -r -- "$dr" | grep -q "certificate root = H\"$sha1_lower\"" \
    || die "designated requirement 不是当前固定证书（期望 $sha1_lower）"
  ok "固定签名与 designated requirement = $sha1_lower"

  (cd "$OUT" && shasum -a 256 -c SHA256SUMS.txt >/dev/null) \
    || die "SHA256SUMS.txt 校验失败"
  ok "SHA256SUMS.txt 校验通过"

  grep -q 'sparkle:edSignature=' "$OUT/appcast.xml" || die "appcast 缺少 EdDSA 签名"
  grep -q "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$OUT/appcast.xml" \
    || die "appcast 的 sparkle:version 不是 $BUILD_NUMBER"
  grep -q "<sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>" "$OUT/appcast.xml" \
    || die "appcast 的 shortVersionString 不是 $VERSION"
  grep -Fq "$DL_PREFIX" "$OUT/appcast.xml" || die "appcast 下载前缀不是 $DL_PREFIX"
  ok "appcast 版本 $VERSION / build $BUILD_NUMBER、下载前缀、EdDSA 签名齐全"

  local sig cast_sig
  sig=$("$SPARKLE_BIN/sign_update" -p --ed-key-file "$KEY_FILE" "$UPDATE_ZIP" 2>/dev/null \
    | tail -1 | tr -d '\r\n' || true)
  cast_sig=$(grep -o 'sparkle:edSignature="[^"]*"' "$OUT/appcast.xml" \
    | sed -E 's/.*="([^"]*)"/\1/')
  [[ -n "$sig" && "$sig" == "$cast_sig" ]] \
    || die "sign_update 复核的 edSignature 与 appcast 不一致（私钥与公钥不匹配？）"
  ok "sign_update 独立复核 edSignature 一致（本机私钥 = 线上公钥）"
}

build_and_sign() {
  if [[ "$SKIP_BUILD" == 0 ]]; then
    info "构建 universal 发布包（arm64 + x86_64，约几分钟）"
    "$ROOT/Build/package-release.sh" universal
  else
    info "跳过构建，复用 $OUT"
    [[ -d "$APP" ]] || die "--skip-build 但产物不存在：$APP"
  fi
  info "生成 appcast（本机私钥文件，非交互，不读钥匙串）"
  DECK_ED_KEY_FILE="$KEY_FILE" "$ROOT/Build/make-appcast.sh" "$OUT" "$DL_PREFIX"
}

# ---- 自检模式：证明本机具备独立发版能力，不改动任何线上状态 ----
verify_only() {
  info "自检模式：不构建、不推 tag、不发布"
  check_credentials
  [[ -s "$UPDATE_ZIP" ]] || die "自检需要现有产物：$UPDATE_ZIP（先执行 ./Build/package-release.sh universal）"

  local online_sig local_sig
  stage=$(mktemp -d)
  trap 'rm -rf "$stage"' EXIT
  cp "$UPDATE_ZIP" "$stage/"
  DECK_ED_KEY_FILE="$KEY_FILE" "$ROOT/Build/make-appcast.sh" "$stage" "$DL_PREFIX" >/dev/null
  local_sig=$(grep -o 'sparkle:edSignature="[^"]*"' "$stage/appcast.xml")
  online_sig=$(curl -fsSL "$FEED_URL" 2>/dev/null | grep -o 'sparkle:edSignature="[^"]*"' || true)
  [[ -n "$online_sig" ]] || die "拉不到线上 appcast：$FEED_URL"
  [[ "$local_sig" == "$online_sig" ]] \
    || die "本机重签的 appcast 签名与线上不一致（$local_sig vs $online_sig）"
  ok "本机私钥重签 appcast 的 edSignature 与线上完全一致"
  verify_artifacts
  print -r -- ""
  print -r -- "自检通过：这台 Mac 已具备独立发版能力（凭据、签名、appcast、校验和全部就绪）。"
  print -r -- "正式发版：./Build/publish-local.sh"
}

publish() {
  check_credentials
  check_repo_state
  build_and_sign
  verify_artifacts

  if [[ "$MODE" == "dry" ]]; then
    print -r -- ""
    print -r -- "dry-run 完成：产物已构建签名并全部校验通过，未推送 tag、未创建 Release。"
    print -r -- "确认无误后执行：./Build/publish-local.sh --skip-build"
    return 0
  fi

  if [[ "$YES" == 0 ]]; then
    [[ -t 0 ]] || die "非交互终端请显式加 --yes"
    print -r -- ""
    print -r -- "即将发布 $TAG（build $BUILD_NUMBER），5 个资产，目标 main@$(git rev-parse --short HEAD)"
    read -q "?确认发布？[y/N] " || die "已取消"
    print -r -- ""
  fi

  local -a notes_args
  notes_args=()
  if [[ -n "$NOTES_FILE" ]]; then
    [[ -s "$NOTES_FILE" ]] || die "说明文件不存在：$NOTES_FILE"
    notes_args=(--notes-file "$NOTES_FILE")
  elif [[ -s "$ROOT/Docs/releases/$VERSION.md" ]]; then
    notes_args=(--notes-file "$ROOT/Docs/releases/$VERSION.md")
  else
    notes_args=(--generate-notes)
  fi

  info "创建 GitHub Release 并上传 5 个资产"
  gh release create "$TAG" \
    "$UPDATE_ZIP" \
    "$OUT/$APP_NAME-$VERSION-universal-installer.zip" \
    "$OUT/$APP_NAME-$VERSION-universal.dmg" \
    "$OUT/appcast.xml" \
    "$OUT/SHA256SUMS.txt" \
    --target main --title "$TAG" "${notes_args[@]}"
  git fetch --tags origin --quiet
  ok "Release 已创建：https://github.com/$REPO/releases/tag/$TAG"

  info "线上复核"
  local names expected
  names=$(gh release view "$TAG" --json assets --jq '.assets[].name' | sort)
  expected=$(printf '%s\n' \
    "appcast.xml" \
    "$APP_NAME-$VERSION-universal-installer.zip" \
    "$APP_NAME-$VERSION-universal.dmg" \
    "$APP_NAME-$VERSION-universal.zip" \
    "SHA256SUMS.txt" | sort)
  [[ "$names" == "$expected" ]] || die "线上资产不齐：\n$names"
  ok "5 个资产齐全"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "$FEED_URL" -o "$tmp/appcast.xml"
  diff -q "$tmp/appcast.xml" "$OUT/appcast.xml" >/dev/null \
    || die "线上 appcast.xml 与本地不一致"
  ok "线上 appcast.xml 与本地完全一致"
  curl -fsSL "$DL_PREFIX/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt"
  diff -q "$tmp/SHA256SUMS.txt" "$OUT/SHA256SUMS.txt" >/dev/null \
    || die "线上 SHA256SUMS.txt 与本地不一致"
  ok "线上 SHA256SUMS.txt 与本地完全一致"

  if [[ "$VERIFY_DOWNLOAD" == 1 ]]; then
    info "下载更新 ZIP 做 SHA256 复核（约 20 MB）"
    curl -fsSL "$DL_PREFIX/$(basename "$UPDATE_ZIP")" -o "$tmp/update.zip"
    local want got
    want=$(grep " $(basename "$UPDATE_ZIP")$" "$OUT/SHA256SUMS.txt" | awk '{print $1}')
    got=$(shasum -a 256 "$tmp/update.zip" | awk '{print $1}')
    [[ "$want" == "$got" ]] || die "线上 ZIP 校验和不匹配"
    ok "线上更新 ZIP SHA256 校验通过"
  fi

  print -r -- ""
  print -r -- "发布完成：$TAG · https://github.com/$REPO/releases/tag/$TAG"
  print -r -- "Sparkle 更新源：$FEED_URL"
}

case "$MODE" in
  verify) verify_only ;;
  *)      publish ;;
esac
