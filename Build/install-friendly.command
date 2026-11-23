#!/bin/zsh
set -u
setopt null_glob

APP_NAME="MacAppControlDeck"
BUNDLE="$APP_NAME.app"
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
TARGET_DIR="${DECK_INSTALL_DIR:-/Applications}"
TARGET="$TARGET_DIR/$BUNDLE"
LOG="/tmp/deck-install.log"
TITLE="MacAppControlDeck 安装"
PET_SETTINGS_URL="macappcontroldeck://settings/pet"
DIALOG_SHOWN=0

: > "$LOG"

say() {
  print -r -- "$1"
  print -r -- "$1" >> "$LOG"
}

show_dialog() {
  DIALOG_SHOWN=1
  if ! osascript -e "display dialog \"$1\" with title \"$2\" buttons {\"好\"} default button 1 with icon ${3:-note}" >/dev/null 2>&1; then
    print -r -- ">>> $2：$1"
  fi
}

on_exit() {
  local last_status=$?
  if [ "$last_status" -ne 0 ] && [ "$DIALOG_SHOWN" -eq 0 ]; then
    show_dialog "安装过程出现意外错误（退出码 $last_status）。请把 /tmp/deck-install.log 发给发送人。" "$TITLE" caution
  fi
}
trap on_exit EXIT

fail() {
  show_dialog "安装没有完成，原因：
$1

如果看不懂，请把 /tmp/deck-install.log 发给发送人。" "$TITLE" caution
  print -r -- "----- 安装日志 $LOG -----"
  tail -40 "$LOG" 2>/dev/null
  print -r -- "按回车键关闭本窗口"
  read -r _
  exit 1
}

find_bundle() {
  local candidate
  for candidate in "$SELF_DIR/$BUNDLE" "$TARGET" "$HOME/Downloads/$BUNDLE" "$HOME/Desktop/$BUNDLE"; do
    if [ -d "$candidate" ]; then
      print -r -- "${candidate:A}"
      return 0
    fi
  done
  for candidate in /Volumes/*/"$BUNDLE"; do
    if [ -d "$candidate" ]; then
      print -r -- "$candidate"
      return 0
    fi
  done
  return 1
}

open_pet_settings() {
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if open "$PET_SETTINGS_URL" >>"$LOG" 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

SRC="$(find_bundle)" || fail "没有找到 $BUNDLE。请把安装脚本和 $BUNDLE 放在同一个文件夹后重试，或先双击 DMG，再从里面的窗口运行安装脚本。"

say "==> 安装包位置：$SRC"

APP_ARCHS="$(lipo -archs "$SRC/Contents/MacOS/$APP_NAME" 2>>"$LOG" | tr ' ' '\n' | tr '\n' ' ')"
MACHINE_ARCH="$(uname -m)"
say "==> 本机架构：$MACHINE_ARCH；应用架构：$APP_ARCHS"

if [ "$MACHINE_ARCH" = "arm64" ] && [[ "$APP_ARCHS" != *arm64* ]]; then
  fail "这台 Mac 是 Apple 芯片，但这个安装包是 Intel 版本。请向发送人索要文件名带 arm64 的安装包。"
fi
if [ "$MACHINE_ARCH" = "x86_64" ] && [[ "$APP_ARCHS" != *x86_64* ]]; then
  fail "这台 Mac 是 Intel 芯片，但这个安装包是 Apple 芯片版本。请向发送人索要文件名带 x86_64 的安装包。"
fi

say "==> 关闭正在运行的旧版本"
pkill -f "$BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null 2>&1
sleep 1

say "==> 复制到 $TARGET"
rm -rf "$TARGET" 2>>"$LOG"
COPY_OK=0
if ditto "$SRC" "$TARGET" >>"$LOG" 2>&1; then
  COPY_OK=1
else
  osascript -e "do shell script \"rm -rf '$TARGET'; /usr/bin/ditto '$SRC' '$TARGET'\" with administrator privileges" >>"$LOG" 2>&1 && COPY_OK=1
fi

if [ "$COPY_OK" != "1" ] || [ ! -d "$TARGET" ]; then
  fail "复制到 $TARGET_DIR 失败，可能是没有权限或磁盘空间不足。"
fi

say "==> 解除 macOS 下载隔离"
xattr -dr com.apple.quarantine "$TARGET" >>"$LOG" 2>&1
xattr -dr com.apple.provenance "$TARGET" >>"$LOG" 2>&1

say "==> 校验签名"
if ! codesign --verify --deep --strict "$TARGET" >>"$LOG" 2>&1; then
  say "==> 传递后签名不完整，使用本机临时签名修复"
  codesign --force --sign - "$TARGET/Contents/MacOS/KeySender" >>"$LOG" 2>&1
  codesign --force --sign - "$TARGET" >>"$LOG" 2>&1
  xattr -dr com.apple.quarantine "$TARGET" >>"$LOG" 2>&1
fi

say "==> 启动应用"
open "$TARGET" >>"$LOG" 2>&1
sleep 5

if ! pgrep -f "$BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
  say "==> 启动失败，收集诊断信息"
  spctl -a -vv "$TARGET" >>"$LOG" 2>&1
  RECENT_CRASH="$(ls -t "$HOME/Library/Logs/DiagnosticReports/${APP_NAME}"* 2>/dev/null | head -1)"
  if [ -n "$RECENT_CRASH" ]; then
    print -r -- "----- 崩溃报告 $RECENT_CRASH -----" >> "$LOG"
    head -40 "$RECENT_CRASH" >> "$LOG" 2>/dev/null
  fi
  show_dialog "应用已经复制到应用程序目录，但没能启动。
请把终端窗口里的内容，或 /tmp/deck-install.log 发给发送人。" "$TITLE" caution
  print -r -- "----- 安装日志 $LOG -----"
  tail -40 "$LOG" 2>/dev/null
  print -r -- "按回车键关闭本窗口"
  read -r _
  exit 1
fi

say "==> 打开桌宠设置"
if open_pet_settings; then
  show_dialog "安装完成，已为你打开「设置 - 桌面宠物」。
在这里可以调整桌宠大小、皮肤和互动方式。

应用没有 Dock 图标，常驻屏幕右上角菜单栏（三条横线加圆点）；关闭设置窗口不会退出程序。" "$TITLE"
else
  show_dialog "安装完成，但没能自动打开桌宠设置。
请点屏幕右上角菜单栏图标（三条横线加圆点）-> 设置 -> 桌面宠物，自己打开一次。" "$TITLE" caution
fi
exit 0
