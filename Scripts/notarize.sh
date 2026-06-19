#!/usr/bin/env bash
# Sign with a Developer ID, notarize and staple — so the app opens WITHOUT a
# Gatekeeper warning when downloaded. Notarizes & staples BOTH the .app and the
# .dmg so it works even offline on first launch.
#
# IMPORTANT: signs in a temp dir, because this repo may live on an iCloud-synced
# folder (Desktop/Documents) whose file provider keeps re-adding
# com.apple.FinderInfo that codesign rejects.
#
# Needs the Apple Developer Program ($99/yr). One-time setup:
#   1) "Developer ID Application" certificate (Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates).
#   2) Notary credential profile (app-specific password):
#        xcrun notarytool store-credentials wallpaps-notary \
#          --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-password"
#
# Usage:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./Scripts/notarize.sh
#   (SIGN_ID may also be the certificate's SHA-1 hash.)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_ID:?SIGN_ID gerekli, örn: 'Developer ID Application: Your Name (TEAMID)' veya SHA-1 hash}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-wallpaps-notary}"
DMG="WallPaps.dmg"

# 1) Fresh build (ad-hoc).
./Scripts/build-app.sh

# 2) Move into a clean (non-iCloud) work dir to sign.
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
APP_W="${WORK}/WallPaps.app"
DMG_W="${WORK}/WallPaps.dmg"
cp -R "WallPaps.app" "${APP_W}"
xattr -cr "${APP_W}"

echo "▶︎ Developer ID ile imzalanıyor (hardened runtime + timestamp)…"
codesign --force --options runtime --timestamp --sign "${SIGN_ID}" "${APP_W}"
codesign --verify --strict --verbose=2 "${APP_W}"

# 3) Notarize the APP, then staple (offline-robust).
echo "▶︎ Uygulama notarize ediliyor (Apple'a gönderiliyor, bekleniyor)…"
ditto -c -k --keepParent "${APP_W}" "${WORK}/app.zip"
xcrun notarytool submit "${WORK}/app.zip" --keychain-profile "${KEYCHAIN_PROFILE}" --wait
xcrun stapler staple "${APP_W}"

# 4) Package the stapled app into a DMG (in the work dir).
echo "▶︎ DMG paketleniyor…"
STAGING="${WORK}/staging"; mkdir -p "${STAGING}"
cp -R "${APP_W}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
hdiutil create -volname "WallPaps" -srcfolder "${STAGING}" -ov -format UDZO "${DMG_W}" >/dev/null

# 5) Notarize + staple the DMG too.
echo "▶︎ DMG notarize ediliyor…"
xcrun notarytool submit "${DMG_W}" --keychain-profile "${KEYCHAIN_PROFILE}" --wait
xcrun stapler staple "${DMG_W}"
xcrun stapler validate "${DMG_W}"

# 6) Verify Gatekeeper acceptance, then copy the final DMG back to the repo.
spctl --assess --type execute -vv "${APP_W}" 2>&1 || true
cp -f "${DMG_W}" "${DMG}"

echo "✓ Notarize + staple tamam: ${DMG} — uyarısız dağıtıma hazır."
