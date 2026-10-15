#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WakeBee"
BUNDLE_ID="io.github.dennisimoo.WakeBeeFree"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${WAKEBEE_DESTINATION:-$ROOT_DIR/dist/$APP_NAME.app}"
CONFIGURATION="${WAKEBEE_BUILD_CONFIGURATION:-debug}"
case "$CONFIGURATION" in debug|release) ;; *) echo "Invalid build configuration" >&2; exit 2 ;; esac
mkdir -p "$ROOT_DIR/dist"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/dist/.WakeBee-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

# A local certificate fingerprint is not a private key. Keep the selection out
# of Git and allow an explicit environment override (including '-' for ad hoc).
if [[ -n "${WAKEBEE_SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$WAKEBEE_SIGN_IDENTITY"
elif [[ -s "$ROOT_DIR/.signing-identity" ]]; then
  SIGN_IDENTITY="$(cat "$ROOT_DIR/.signing-identity")"
else
  SIGN_IDENTITY="-"
fi

case "$MODE" in
  run|--build-only|--verify|--logs|--telemetry|--debug) ;;
  *) echo "Usage: $0 [--build-only|--verify|--logs|--telemetry|--debug]" >&2; exit 2 ;;
esac

cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

if [[ "$MODE" != "--build-only" ]]; then
  # Retire earlier display names too so Run never leaves duplicate menu items.
  for PROCESS_NAME in "$APP_NAME" Untiring AwakeMac; do
    pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true
  done
else
  python3 "$ROOT_DIR/script/check_build_destination.py" "$DESTINATION/Contents/MacOS/$APP_NAME"
fi

BUILD_ARGS=(--disable-sandbox --configuration "$CONFIGURATION")
if [[ "${WAKEBEE_UNIVERSAL:-0}" == "1" ]]; then BUILD_ARGS+=(--arch arm64 --arch x86_64); fi
swift build "${BUILD_ARGS[@]}"
BUILD_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
if [[ ! -f "$ROOT_DIR/Resources/WakeBee.icns" ||
      "$ROOT_DIR/Resources/WakeBee.png" -nt "$ROOT_DIR/Resources/WakeBee.icns" ||
      "$ROOT_DIR/script/create_icon.swift" -nt "$ROOT_DIR/Resources/WakeBee.icns" ]]; then
  swift "$ROOT_DIR/script/create_icon.swift" "$ROOT_DIR/.build/WakeBee.iconset"
  iconutil -c icns "$ROOT_DIR/.build/WakeBee.iconset" -o "$ROOT_DIR/Resources/WakeBee.icns"
fi

mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources" "$APP_CONTENTS/Library/HelperTools" "$APP_CONTENTS/Library/LaunchDaemons"
cp "$ROOT_DIR/LICENSE" "$APP_CONTENTS/Resources/WakeBee-LICENSE.txt"
cp "$BUILD_DIR/$APP_NAME" "$APP_BINARY"
# Retire task-integration executables when updating an earlier bundle in place.
rm -f "$APP_CONTENTS/MacOS/awakemac-hook" "$APP_CONTENTS/MacOS/awakemac-activity"
cp "$BUILD_DIR/WakeBeeHelper" "$APP_CONTENTS/Library/HelperTools/WakeBeeHelper"
cp "$ROOT_DIR/Resources/io.github.dennisimoo.WakeBeeFree.helper.plist" "$APP_CONTENTS/Library/LaunchDaemons/"
cp "$ROOT_DIR/script/manage-helper.sh" "$ROOT_DIR/script/code_requirement.sh" "$APP_CONTENTS/Resources/"
cp "$ROOT_DIR/Resources/WakeBee.icns" "$APP_CONTENTS/Resources/"
chmod +x "$APP_BINARY"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
/usr/bin/plutil -lint "$APP_CONTENTS/Info.plist"

# Pin the helper after ad-hoc signing, then seal that requirement in the app.
SIGN_OPTIONS=(--force --sign "$SIGN_IDENTITY" --options runtime,kill)
if [[ "$SIGN_IDENTITY" != "-" ]]; then SIGN_OPTIONS+=(--timestamp); fi
codesign "${SIGN_OPTIONS[@]}" --identifier "io.github.dennisimoo.WakeBeeFree.helper" "$APP_CONTENTS/Library/HelperTools/WakeBeeHelper"
/bin/bash "$ROOT_DIR/script/code_requirement.sh" "$APP_CONTENTS/Library/HelperTools/WakeBeeHelper" > "$APP_CONTENTS/Resources/helper-requirement.txt"
codesign "${SIGN_OPTIONS[@]}" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

# Never expose a half-written or temporarily unsigned bundle to launchd.
# Keep the prior bundle intact until its replacement has passed signing checks.
# A running process still uses the old signed executable. Replacing its bundle
# can make SMAppService registration fail with EINVAL until that process exits.
# Check again here in case the destination was opened during the build.
python3 "$ROOT_DIR/script/check_build_destination.py" "$DESTINATION/Contents/MacOS/$APP_NAME"
mkdir -p "$(dirname "$DESTINATION")"
if [[ -e "$DESTINATION" ]]; then mv "$DESTINATION" "$STAGING_DIR/Previous.app"; fi
if ! mv "$APP_BUNDLE" "$DESTINATION"; then
  if [[ -e "$STAGING_DIR/Previous.app" ]]; then mv "$STAGING_DIR/Previous.app" "$DESTINATION"; fi
  exit 1
fi
APP_BUNDLE="$DESTINATION"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

case "$MODE" in
  --build-only) echo "Built $APP_BUNDLE" ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "WakeBee is running: $APP_BUNDLE"
    ;;
  --debug) lldb -- "$APP_BINARY" ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
esac
