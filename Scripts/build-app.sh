#!/usr/bin/env bash
# Builds WallPaps and wraps the SwiftPM binary into a proper .app bundle
# (LSUIElement menu-bar agent), then ad-hoc code-signs it so it can run.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="WallPaps"
BUNDLE_ID="com.local.wallpaps"
VERSION="1.0.1"

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
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# --- App icon -------------------------------------------------------------
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
</dict>
</plist>
PLIST

echo "▶︎ Ad-hoc imzalanıyor…"
# sips/iconutil can leave extended attributes that codesign rejects.
xattr -cr "${APP_DIR}" 2>/dev/null || true
if codesign --force --sign - "${APP_DIR}" >/dev/null 2>&1; then
  echo "  ✓ imzalandı (ad-hoc)"
else
  echo "  (uyarı: codesign atlandı; uygulama yine de çalışır)"
fi

echo "✓ Hazır: ${APP_DIR}"
echo "  Çalıştır:   open ${APP_DIR}"
echo "  Kur:        cp -R ${APP_DIR} /Applications/"
