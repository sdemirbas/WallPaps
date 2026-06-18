#!/usr/bin/env bash
# Builds (if needed) and packages WallPaps.app into a drag-to-install DMG.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="WallPaps.app"
DMG="WallPaps.dmg"
VOL="WallPaps"

# Always rebuild so the DMG reflects the latest code.
./Scripts/build-app.sh

echo "▶︎ DMG hazırlanıyor…"
STAGING="$(mktemp -d)"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
xattr -cr "${STAGING}/${APP}" 2>/dev/null || true

rm -f "${DMG}"
hdiutil create -volname "${VOL}" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" >/dev/null
rm -rf "${STAGING}"

echo "✓ Hazır: ${DMG} ($(du -h "${DMG}" | cut -f1 | tr -d ' '))"
echo "  Kurulum: DMG'yi aç → WallPaps'i Applications'a sürükle."
echo "  Genel yayın öncesi imzalama/notarization için: ./Scripts/notarize.sh"
