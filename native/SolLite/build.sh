#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/Sol Lite.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$BUILD"
mkdir -p "$MACOS" "$CONTENTS/Resources"
cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

swiftc -O \
  -framework AppKit \
  -framework Carbon \
  "$ROOT/Sources/SolLite/main.swift" \
  -o "$MACOS/Sol Lite"

codesign --force --deep --sign - "$APP" >/dev/null
printf '%s\n' "$APP"
