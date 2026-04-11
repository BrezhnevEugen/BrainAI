#!/usr/bin/env bash
# BrainAI release: build, wrap SPM binaries as .app bundles, optional codesign + notarization, DMG.
#
# SwiftPM produces bare Mach-O files + Sparkle.framework in the build directory. Finder / Gatekeeper
# treat those as broken "apps" unless they are packaged as .app with Info.plist and bundled deps.
#
# Usage:
#   ./scripts/build-and-sign.sh [version]
#   VERSION=0.2.0 ./scripts/build-and-sign.sh
#   Из корня монорепо: ../scripts/build-and-sign.sh (см. обёртку; задайте DIST при необходимости)
#   CODESIGN_IDENTITY="Developer ID Application: …" ./scripts/build-and-sign.sh
#   NOTARIZE=1 NOTARY_KEYCHAIN_PROFILE=… ./scripts/build-and-sign.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-${VERSION:-0.1.0}}"
CONFIG="${CONFIG:-release}"
DIST="${DIST:-$ROOT/dist}"
STAGE="$DIST/stage/BrainAI-$VERSION"
BUNDLE_ID_PREFIX="${BUNDLE_ID_PREFIX:-com.brainai}"
SUFeedURL="${SUFeedURL:-https://github.com/BrainAI-App/BrainAI/releases/latest/download/appcast.xml}"

echo "==> Swift build ($CONFIG, all app products)"
swift build -c "$CONFIG" \
  --product BrainAITray \
  --product BrainAISettings \
  --product BrainAIApp \
  --product BrainAIInstaller

BIN_DIR="$(swift build -c "$CONFIG" --product BrainAIApp --show-bin-path)"
echo "==> Binaries: $BIN_DIR"

SPARKLE_FW="$BIN_DIR/Sparkle.framework"
RES_BUNDLE="$BIN_DIR/BrainAI_BrainAICore.bundle"
# SwiftPM resource bundle for the installer target (Localizable.strings per locale).
INSTALLER_RES_BUNDLE="$BIN_DIR/BrainAI_BrainAIInstaller.bundle"
if [[ ! -d "$SPARKLE_FW" ]]; then
  echo "error: Sparkle.framework not found in $BIN_DIR (SwiftPM release output)." >&2
  exit 1
fi
if [[ ! -d "$RES_BUNDLE" ]]; then
  echo "error: BrainAI_BrainAICore.bundle not found in $BIN_DIR." >&2
  exit 1
fi
if [[ ! -d "$INSTALLER_RES_BUNDLE" ]]; then
  echo "error: BrainAI_BrainAIInstaller.bundle not found in $BIN_DIR (installer localization)." >&2
  exit 1
fi

rm -rf "$DIST/stage"
mkdir -p "$STAGE"

# Finder alias (optional, common DMG layout)
ln -sf /Applications "$STAGE/Applications"

plist_set_string() {
  local plist="$1" key="$2" val="$3"
  if plutil -extract "$key" xml1 "$plist" >/dev/null 2>&1; then
    plutil -replace "$key" -string "$val" "$plist"
  else
    plutil -insert "$key" -string "$val" "$plist"
  fi
}

plist_set_bool() {
  local plist="$1" key="$2" val="$3"
  if plutil -extract "$key" xml1 "$plist" >/dev/null 2>&1; then
    plutil -replace "$key" -bool "$val" "$plist"
  else
    plutil -insert "$key" -bool "$val" "$plist"
  fi
}

plist_set_localizations() {
  local plist="$1"
  if plutil -extract CFBundleLocalizations xml1 "$plist" >/dev/null 2>&1; then
    plutil -replace CFBundleLocalizations -json '["en","ru","uk"]' "$plist"
  else
    plutil -insert CFBundleLocalizations -json '["en","ru","uk"]' "$plist"
  fi
}

# Assemble one .app: executable name inside MacOS may differ from SPM product (e.g. BrainAI vs BrainAIApp).
assemble_app() {
  local app_name="$1"
  local bundle_id="$2"
  local exec_in_macos="$3"
  local src_macho="$4"
  local lsui="$5"

  local app_path="$STAGE/$app_name"
  mkdir -p "$app_path/Contents/MacOS"

  cp "$src_macho" "$app_path/Contents/MacOS/$exec_in_macos"
  chmod +x "$app_path/Contents/MacOS/$exec_in_macos"
  rm -rf "$app_path/Contents/MacOS/Sparkle.framework" "$app_path/Contents/MacOS/BrainAI_BrainAICore.bundle" \
    "$app_path/Contents/MacOS/BrainAI_BrainAIInstaller.bundle"
  cp -R "$SPARKLE_FW" "$app_path/Contents/MacOS/"
  cp -R "$RES_BUNDLE" "$app_path/Contents/MacOS/"
  # Installer strings live in this SPM bundle; must sit next to the Mach-O (same as swift build output).
  if [[ "$exec_in_macos" == "BrainAIInstaller" ]]; then
    cp -R "$INSTALLER_RES_BUNDLE" "$app_path/Contents/MacOS/"
  fi

  local info="$app_path/Contents/Info.plist"
  plutil -create xml1 "$info"
  plist_set_string "$info" CFBundleDevelopmentRegion "en"
  plist_set_string "$info" CFBundleExecutable "$exec_in_macos"
  plist_set_string "$info" CFBundleIdentifier "$bundle_id"
  plist_set_string "$info" CFBundleInfoDictionaryVersion "6.0"
  plist_set_string "$info" CFBundleName "${app_name%.app}"
  plist_set_string "$info" CFBundlePackageType "APPL"
  plist_set_string "$info" CFBundleShortVersionString "$VERSION"
  plist_set_string "$info" CFBundleVersion "$VERSION"
  plist_set_string "$info" LSMinimumSystemVersion "14.0"
  plist_set_bool "$info" NSHighResolutionCapable true
  plist_set_string "$info" SUFeedURL "$SUFeedURL"
  if [[ "$lsui" == "true" ]]; then
    plist_set_bool "$info" LSUIElement true
  fi

  # So macOS treats the app as multilingual (helps locale resolution for bundled resources).
  if [[ "$exec_in_macos" == "BrainAIInstaller" ]]; then
    plist_set_localizations "$info"
  fi

  printf '%s' "APPL????" >"$app_path/Contents/PkgInfo"
}

assemble_app "BrainAI.app" "$BUNDLE_ID_PREFIX.app" "BrainAI" "$BIN_DIR/BrainAIApp" "false"
assemble_app "BrainAI Tray.app" "$BUNDLE_ID_PREFIX.tray" "BrainAITray" "$BIN_DIR/BrainAITray" "true"
assemble_app "BrainAI Settings.app" "$BUNDLE_ID_PREFIX.settings" "BrainAISettings" "$BIN_DIR/BrainAISettings" "false"
assemble_app "BrainAI Installer.app" "$BUNDLE_ID_PREFIX.installer" "BrainAIInstaller" "$BIN_DIR/BrainAIInstaller" "false"

if [[ -f "$ROOT/README.md" ]]; then
  cp "$ROOT/README.md" "$STAGE/README.txt"
fi

sign_if_needed() {
  local target="$1"
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    return 0
  fi
  echo "==> codesign: $target"
  codesign --force --timestamp --options runtime \
    --sign "$CODESIGN_IDENTITY" \
    "$target"
}

sign_app() {
  local app="$1"
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    return 0
  fi
  local fw="$app/Contents/MacOS/Sparkle.framework"
  local rb="$app/Contents/MacOS/BrainAI_BrainAICore.bundle"
  local inst_rb="$app/Contents/MacOS/BrainAI_BrainAIInstaller.bundle"
  [[ -d "$fw" ]] && sign_if_needed "$fw"
  [[ -d "$rb" ]] && sign_if_needed "$rb"
  [[ -d "$inst_rb" ]] && sign_if_needed "$inst_rb"
  # Sign each Mach-O inside MacOS (executable only; avoid re-signing framework copies)
  local m="$app/Contents/MacOS"
  local f
  for f in "$m"/*; do
    [[ -f "$f" ]] && [[ -x "$f" ]] || continue
    [[ "$f" == "$m/Sparkle.framework" ]] && continue
    [[ "$f" == "$m/BrainAI_BrainAICore.bundle" ]] && continue
    [[ "$f" == "$m/BrainAI_BrainAIInstaller.bundle" ]] && continue
    sign_if_needed "$f"
  done
  sign_if_needed "$app"
}

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  for app in \
    "$STAGE/BrainAI.app" \
    "$STAGE/BrainAI Tray.app" \
    "$STAGE/BrainAI Settings.app" \
    "$STAGE/BrainAI Installer.app"; do
    [[ -d "$app" ]] && sign_app "$app"
  done
fi

DMG_PATH="$DIST/BrainAI-$VERSION.dmg"
mkdir -p "$DIST"
rm -f "$DMG_PATH"

echo "==> Creating DMG: $DMG_PATH"
hdiutil create -volname "BrainAI $VERSION" -srcfolder "$STAGE" \
  -ov -format UDZO "$DMG_PATH" >/dev/null

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  sign_if_needed "$DMG_PATH"
fi

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  if [[ -z "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    echo "NOTARIZE=1 requires NOTARY_KEYCHAIN_PROFILE (notarytool store-credentials)." >&2
    exit 1
  fi
  echo "==> notarytool submit (wait)"
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait
  xcrun stapler staple "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
