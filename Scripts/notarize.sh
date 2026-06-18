#!/usr/bin/env bash
# Sign with a Developer ID, notarize and staple — required to distribute the app
# publicly so it opens WITHOUT a Gatekeeper warning.
#
# Needs the Apple Developer Program ($99/yr). One-time setup:
#   1) Install a "Developer ID Application" certificate (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates).
#   2) Store a notary credential profile (uses an app-specific password):
#        xcrun notarytool store-credentials wallpaps-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#
# Usage:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./Scripts/notarize.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_ID:?SIGN_ID gerekli, örn: 'Developer ID Application: Your Name (TEAMID)'}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-wallpaps-notary}"
APP="WallPaps.app"
DMG="WallPaps.dmg"

# 1) Fresh build (ad-hoc), then re-sign with Developer ID + hardened runtime.
./Scripts/build-app.sh
echo "▶︎ Developer ID ile imzalanıyor (hardened runtime + timestamp)…"
xattr -cr "${APP}"
codesign --force --deep --options runtime --timestamp --sign "${SIGN_ID}" "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

# 2) Package the (Developer-ID-signed) app into a DMG (inline, so the signature
#    is preserved — we must NOT re-run build-app.sh here).
echo "▶︎ DMG paketleniyor…"
STAGING="$(mktemp -d)"
cp -R "${APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
rm -f "${DMG}"
hdiutil create -volname "WallPaps" -srcfolder "${STAGING}" -ov -format UDZO "${DMG}" >/dev/null
rm -rf "${STAGING}"

# 3) Notarize the DMG and staple the ticket.
echo "▶︎ Notarize ediliyor (Apple sunucusuna gönderiliyor, bekleniyor)…"
xcrun notarytool submit "${DMG}" --keychain-profile "${KEYCHAIN_PROFILE}" --wait

echo "▶︎ Staple ediliyor…"
xcrun stapler staple "${DMG}"
xcrun stapler validate "${DMG}"

echo "✓ Notarize + staple tamam: ${DMG} — genel dağıtıma hazır."
