#!/usr/bin/env bash
# Generates (or updates) appcast.xml from a signed DMG using Sparkle's
# generate_appcast tool. Run after notarize.sh.
#
# Prerequisites:
#   1. Sparkle's generate_appcast in PATH or pointed to by SPARKLE_BIN.
#      It ships inside Sparkle.framework: Sparkle.framework/Versions/B/Resources/generate_appcast
#   2. The EdDSA private key stored at the path in ED_KEY_FILE
#      (generate once with: generate_keys — never commit to the repo).
#
# Usage:
#   ED_KEY_FILE=~/.sparkle/wallpaps-ed.key \
#   RELEASE_TAG=v1.0.2 \
#   GITHUB_REPO=sdemirbas/WallPaps \
#   ./Scripts/generate-appcast.sh
#
# The resulting appcast.xml is written to the repo root. Commit and push it
# so the SUFeedURL in the app can find it.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${ED_KEY_FILE:?Set ED_KEY_FILE to your Sparkle EdDSA private key file path}"
: "${RELEASE_TAG:?Set RELEASE_TAG, e.g. v1.0.2}"
: "${GITHUB_REPO:?Set GITHUB_REPO, e.g. sdemirbas/WallPaps}"

DMG="WallPaps.dmg"
if [[ ! -f "${DMG}" ]]; then
  echo "✗ ${DMG} bulunamadı. Önce notarize.sh çalıştırın." >&2
  exit 1
fi

# Find generate_appcast from Sparkle artifacts or PATH
SPARKLE_BIN="${SPARKLE_BIN:-}"
if [[ -z "${SPARKLE_BIN}" ]]; then
  SPARKLE_BIN=$(find .build/artifacts -name "generate_appcast" 2>/dev/null | head -1)
fi
if [[ -z "${SPARKLE_BIN}" ]]; then
  SPARKLE_BIN=$(command -v generate_appcast 2>/dev/null || true)
fi
if [[ -z "${SPARKLE_BIN}" ]]; then
  echo "✗ generate_appcast bulunamadı. SPARKLE_BIN değişkenini ayarlayın veya PATH'e ekleyin." >&2
  exit 1
fi

DOWNLOAD_PREFIX="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/"

echo "▶︎ appcast.xml üretiliyor…"
"${SPARKLE_BIN}" \
  --ed-key-file "${ED_KEY_FILE}" \
  --download-url-prefix "${DOWNLOAD_PREFIX}" \
  --output appcast.xml \
  . # scan current dir for DMG

echo "✓ appcast.xml güncellendi. Commit edip push yapın:"
echo "  git add appcast.xml && git commit -m 'chore: appcast ${RELEASE_TAG}' && git push"
