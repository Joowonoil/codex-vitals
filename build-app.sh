#!/usr/bin/env bash
# Builds the local Swift release .app with configurable display metadata.
#
# Optional variables:
#   PRODUCT_NAME  App bundle filename without .app.
#   DISPLAY_NAME  Finder / Spotlight name.
#   BUNDLE_ID     CFBundleIdentifier.
#   VERSION       CFBundleShortVersionString and CFBundleVersion.
#   INSTALL_APPS  If 1, copies the generated app to /Applications.
#   SIGN_IDENTITY Code signing identity. Defaults to ad-hoc signing (-).
#
# Usage:
#   ./build-app.sh
#   DISPLAY_NAME="Codex Vitals" PRODUCT_NAME="CodexVitals" ./build-app.sh
#
# Signing note: this script uses ad-hoc local signing only. Public distribution
# builds should use a Developer ID signing and notarization flow.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

PRODUCT_NAME="${PRODUCT_NAME:-CodexVitals}"
DISPLAY_NAME="${DISPLAY_NAME:-Codex Vitals}"
BUNDLE_ID="${BUNDLE_ID:-app.codexvitals.menubar}"
VERSION="${VERSION:-1.2}"
INSTALL_APPS="${INSTALL_APPS:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ICNS="${ROOT}/Support/AppIcon.icns"
if [[ ! -f "$ICNS" ]]; then
	echo "Generating AppIcon.icns..."
	"${ROOT}/Support/make-icns.sh"
fi

echo "swift build -c release ..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
EXE="${BIN_DIR}/CodexVitals"
if [[ ! -x "$EXE" ]]; then
	echo "error: executable not found: $EXE" >&2
	exit 1
fi

OUT="${ROOT}/dist/${PRODUCT_NAME}.app"
rm -rf "$OUT"
mkdir -p "${OUT}/Contents/MacOS" "${OUT}/Contents/Resources"
cp "$EXE" "${OUT}/Contents/MacOS/CodexVitals"
chmod +x "${OUT}/Contents/MacOS/CodexVitals"
cp "${ROOT}/Support/Info.plist" "${OUT}/Contents/Info.plist"
cp "$ICNS" "${OUT}/Contents/Resources/AppIcon.icns"
cp "${ROOT}/Support/codex.png" "${OUT}/Contents/Resources/codex.png"
cp "${ROOT}/Support/RamterStudioLogo.png" "${OUT}/Contents/Resources/RamterStudioLogo.png"

PLIST="${OUT}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${DISPLAY_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName ${DISPLAY_NAME}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$PLIST"

if command -v codesign &>/dev/null; then
	if [[ "$SIGN_IDENTITY" == "-" ]]; then
		codesign --force --deep --sign - "$OUT" 2>/dev/null || true
	else
		codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$OUT"
	fi
fi

echo "OK: $OUT"
echo "   Open: open \"$OUT\""
echo "   Spotlight: search for \"${DISPLAY_NAME}\"."

if [[ "$INSTALL_APPS" == "1" ]]; then
	DEST="/Applications/${PRODUCT_NAME}.app"
	rm -rf "$DEST"
	cp -R "$OUT" "$DEST"
	echo "Installed: $DEST"
fi
