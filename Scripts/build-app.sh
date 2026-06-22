#!/usr/bin/env bash
# Builds WallPaps and wraps the SwiftPM binary into a proper .app bundle
# (LSUIElement menu-bar agent), then ad-hoc code-signs it so it can run.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="WallPaps"
BUNDLE_ID="com.local.wallpaps"
VERSION="1.0.3"

# EdDSA public key — generated via Sparkle's generate_keys tool.
# Private key is in macOS Keychain ("Private key for signing Sparkle updates")
# and stored as SPARKLE_ED_PRIVATE_KEY in GitHub Secrets for CI.
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-dn+oa5Nn8zgPy7panM9+Qf8qV478Zi94GEs4+AU9MXM=}"

# Appcast URL served from the repo (raw GitHub content).
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://raw.githubusercontent.com/sdemirbas/WallPaps/main/appcast.xml}"

echo "▶︎ Derleniyor (release)…"
swift build -c release

BIN_PATH=".build/release/${APP_NAME}"
if [[ ! -f "${BIN_PATH}" ]]; then
  echo "✗ Derleme çıktısı bulunamadı: ${BIN_PATH}" >&2
  exit 1
fi

APP_DIR="${APP_NAME}.app"
echo "▶︎ ${APP_DIR} paketleniyor…"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources" "${APP_DIR}/Contents/Frameworks"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# --- Sparkle.framework -------------------------------------------------------
# SwiftPM places binary XCFramework artifacts under .build/artifacts.
SPARKLE_FW=$(find .build/artifacts -name "Sparkle.framework" -type d 2>/dev/null | head -1)
if [[ -z "${SPARKLE_FW}" ]]; then
  # Fallback: resolved checkouts path used in some SwiftPM versions
  SPARKLE_FW=$(find .build/checkouts -name "Sparkle.framework" -type d 2>/dev/null | head -1)
fi
if [[ -n "${SPARKLE_FW}" ]]; then
  echo "▶︎ Sparkle.framework gömülüyor: ${SPARKLE_FW}"
  cp -R "${SPARKLE_FW}" "${APP_DIR}/Contents/Frameworks/"
  # Ensure the binary can find the framework at runtime.
  install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "${APP_DIR}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
else
  echo "  (uyarı: Sparkle.framework bulunamadı — önce 'swift build' çalıştırın)"
fi

# --- App icon ----------------------------------------------------------------
HAS_ICON=0
echo "▶︎ İkon üretiliyor…"
ICON_SRC=".build/wallpaps-icon-1024.png"
if "${BIN_PATH}" --makeicon "${ICON_SRC}" >/dev/null 2>&1 && [[ -f "${ICON_SRC}" ]]; then
  ICONSET=".build/AppIcon.iconset"
  rm -rf "${ICONSET}"; mkdir -p "${ICONSET}"
  for sz in 16 32 128 256 512; do
    sips -z "${sz}" "${sz}"   "${ICON_SRC}" --out "${ICONSET}/icon_${sz}x${sz}.png"    >/dev/null 2>&1
    d=$(( sz * 2 ))
    sips -z "${d}" "${d}"     "${ICON_SRC}" --out "${ICONSET}/icon_${sz}x${sz}@2x.png" >/dev/null 2>&1
  done
  if iconutil -c icns "${ICONSET}" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" >/dev/null 2>&1; then
    HAS_ICON=1
  else
    echo "  (uyarı: iconutil başarısız; ikon atlandı)"
  fi
else
  echo "  (uyarı: ikon üretilemedi; atlanıyor)"
fi

ICON_PLIST=""
if [[ "${HAS_ICON}" == "1" ]]; then
  ICON_PLIST="    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundleIconName</key>        <string>AppIcon</string>"
fi

SPARKLE_PUBLIC_KEY_PLIST=""
if [[ -n "${SPARKLE_PUBLIC_KEY}" ]]; then
  SPARKLE_PUBLIC_KEY_PLIST="    <key>SUPublicEDKey</key>           <string>${SPARKLE_PUBLIC_KEY}</string>"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>     <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>      <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>      <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>${VERSION}</string>
    <key>CFBundleVersion</key>         <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
${ICON_PLIST}
    <!-- Menu-bar agent: no Dock icon, no main window. -->
    <key>LSUIElement</key>             <true/>

    <!-- Sparkle auto-update -->
    <key>SUFeedURL</key>               <string>${SPARKLE_FEED_URL}</string>
    <key>SUEnableAutomaticChecks</key> <true/>
${SPARKLE_PUBLIC_KEY_PLIST}
</dict>
</plist>
PLIST

echo "▶︎ Ad-hoc imzalanıyor…"
xattr -cr "${APP_DIR}" 2>/dev/null || true
# Sign Sparkle.framework first (inside-out signing required by Apple)
if [[ -d "${APP_DIR}/Contents/Frameworks/Sparkle.framework" ]]; then
  codesign --force --sign - "${APP_DIR}/Contents/Frameworks/Sparkle.framework" >/dev/null 2>&1 || true
fi
if codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1; then
  echo "  ✓ imzalandı (ad-hoc)"
else
  echo "  (uyarı: codesign atlandı; uygulama yine de çalışır)"
fi

echo "✓ Hazır: ${APP_DIR}"
echo "  Çalıştır:   open ${APP_DIR}"
echo "  Kur:        cp -R ${APP_DIR} /Applications/"
