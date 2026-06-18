#!/usr/bin/env bash
# TEMPLATE — Mac App Store build (sandboxed). NOT part of the normal DMG flow.
# Requires the Apple Developer Program + App Store distribution certificates and
# an App Store Connect app record. Full submission (provisioning, screenshots,
# review) is done from your account; this script just produces the signed .pkg.
#
# Prerequisites:
#   - "3rd Party Mac Developer Application: NAME (TEAMID)"  (app signing)
#   - "3rd Party Mac Developer Installer: NAME (TEAMID)"    (pkg signing)
#   - A provisioning profile embedded as WallPaps.app/Contents/embedded.provisionprofile
#
# Usage:
#   APP_CERT="3rd Party Mac Developer Application: NAME (TEAMID)" \
#   INSTALLER_CERT="3rd Party Mac Developer Installer: NAME (TEAMID)" \
#   ./Scripts/build-appstore.sh
set -euo pipefail
cd "$(dirname "$0")/.."

: "${APP_CERT:?APP_CERT gerekli}"
: "${INSTALLER_CERT:?INSTALLER_CERT gerekli}"
APP="WallPaps.app"
PKG="WallPaps.pkg"
ENTITLEMENTS="WallPaps.entitlements"

# Build the bundle (ad-hoc), then re-sign sandboxed with the App Store cert + entitlements.
./Scripts/build-app.sh
echo "▶︎ App Store sertifikasıyla (sandbox + entitlements) imzalanıyor…"
xattr -cr "${APP}"
# NOTE: embed your provisioning profile before signing:
#   cp WallPaps.provisionprofile "${APP}/Contents/embedded.provisionprofile"
codesign --force --options runtime --timestamp \
  --entitlements "${ENTITLEMENTS}" --sign "${APP_CERT}" "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

echo "▶︎ .pkg üretiliyor…"
productbuild --component "${APP}" /Applications --sign "${INSTALLER_CERT}" "${PKG}"

echo "✓ ${PKG} hazır — App Store Connect'e 'xcrun altool/notarytool' veya Transporter ile yükle."
