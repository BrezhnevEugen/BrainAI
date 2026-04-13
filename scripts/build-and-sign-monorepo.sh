#!/usr/bin/env bash
# Для раскладки «родительская папка /BrainAI/клон с Package.swift» (например ~/dev_soft/BrainAI/BrainAI).
# Кладёт dist/ в родительскую папку. Из корня монорепо: ../BrainAI/scripts/build-and-sign-monorepo.sh
#
# Usage (из ~/dev_soft/BrainAI):
#   ../BrainAI/scripts/build-and-sign-monorepo.sh
# или скопируйте этот файл в ./scripts/build-and-sign.sh рядом с каталогом BrainAI/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INNER="$PACKAGE_ROOT/scripts/build-and-sign.sh"

if [[ ! -f "$PACKAGE_ROOT/Package.swift" ]]; then
  echo "error: Package.swift не найден в $PACKAGE_ROOT" >&2
  exit 1
fi
if [[ ! -f "$INNER" ]]; then
  echo "error: не найден $INNER" >&2
  exit 1
fi

export VERSION="${1:-${VERSION:-0.1.6}}"
SKIP_SIGNING="${SKIP_SIGNING:-false}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-false}"
export DIST="${DIST:-$REPO_ROOT/dist}"

if [[ "$SKIP_SIGNING" == "true" ]]; then
  unset CODESIGN_IDENTITY
else
  export CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-${SIGNING_IDENTITY:-Developer ID Application}}"
fi

if [[ "$SKIP_SIGNING" == "true" ]]; then
  export NOTARIZE=0
elif [[ "$SKIP_NOTARIZE" == "true" ]]; then
  export NOTARIZE=0
else
  export NOTARIZE="${NOTARIZE:-1}"
fi

echo "=== BrainAI Build & Package (monorepo layout) ==="
echo "Version: $VERSION"
echo "Package: $PACKAGE_ROOT"
echo "Dist:    $DIST"
echo "Skip signing: $SKIP_SIGNING"
echo "Skip notarize: $SKIP_NOTARIZE"
echo "NOTARIZE: ${NOTARIZE:-0}"
echo ""

exec bash "$INNER"
