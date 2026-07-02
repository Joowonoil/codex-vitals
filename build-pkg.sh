#!/usr/bin/env bash
# Builds a macOS .pkg installer from the local .app bundle.
#
# Optional variables:
#   PRODUCT_NAME   App bundle filename without .app.
#   BUNDLE_ID      CFBundleIdentifier (also used as pkg identifier).
#   PKG_NAME       Output .pkg filename.
#   VERSION        Output/package display version string.
#   PACKAGE_VERSION pkgbuild-compatible package version. Defaults to VERSION without prerelease suffix.
#   PKG_SIGN_IDENTITY Developer ID Installer identity for signed packages.
#
# Usage:
#   ./build-pkg.sh
#   VERSION=1.2.1 ./build-pkg.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

PRODUCT_NAME="${PRODUCT_NAME:-CodexVitals}"
BUNDLE_ID="${BUNDLE_ID:-app.codexvitals.menubar}"
PKG_NAME="${PKG_NAME:-CodexVitals}"
VERSION="${VERSION:-1.2.1}"
PACKAGE_VERSION="${PACKAGE_VERSION:-${VERSION%%-*}}"
PKG_SIGN_IDENTITY="${PKG_SIGN_IDENTITY:-}"

APP_SRC="${ROOT}/dist/${PRODUCT_NAME}.app"
if [[ ! -d "$APP_SRC" ]]; then
	echo "error: .app not found at $APP_SRC — run ./build-app.sh first." >&2
	exit 1
fi

OUT_DIR="${ROOT}/dist"
mkdir -p "$OUT_DIR"

PKG_OUT="${OUT_DIR}/${PKG_NAME}-${VERSION}.pkg"
rm -f "$PKG_OUT"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

ditto --noextattr --norsrc "$APP_SRC" "${STAGE}/${PRODUCT_NAME}.app"
xattr -cr "${STAGE}/${PRODUCT_NAME}.app" 2>/dev/null || true
find "$STAGE" \( -name '.DS_Store' -o -name '._*' \) -delete

echo "Building installer package..."
PKGBUILD_ARGS=(
	--root "$STAGE"
	--install-location /Applications
	--identifier "$BUNDLE_ID"
	--version "$PACKAGE_VERSION"
	--filter '/\._[^/]*$'
	--filter '/\.DS_Store$'
)
if [[ -n "$PKG_SIGN_IDENTITY" ]]; then
	PKGBUILD_ARGS+=(--sign "$PKG_SIGN_IDENTITY" --timestamp)
fi

COPYFILE_DISABLE=1 pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_OUT"

echo "OK: $PKG_OUT"
echo "   Install: sudo installer -pkg \"$PKG_OUT\" -target /"
