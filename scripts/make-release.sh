#!/bin/bash
# Builds a universal RadioAtlas.app and zips it for distribution, so people
# can run the app without installing a Swift toolchain.
#
# The zip is ad-hoc signed, not notarized, so macOS will warn on first launch
# and the user has to allow it once in System Settings. Notarizing instead
# needs a paid Apple Developer Program membership and a "Developer ID
# Application" certificate; an "Apple Development" certificate cannot do it.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo 0.1.0)}"
OUT="$ROOT/.build/release-artifacts"

"$ROOT/scripts/make-app.sh" --universal

APP="$ROOT/.build/RadioAtlas.app"
rm -rf "$OUT" && mkdir -p "$OUT"
ZIP="$OUT/RadioAtlas-$VERSION-universal.zip"

# ditto, not `zip`: it preserves the bundle's symlinks, extended attributes
# and code signature, which a plain zip mangles.
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "==> Release artifact"
echo "    $ZIP"
echo "    size:   $(du -h "$ZIP" | cut -f1)"
echo "    archs:  $(lipo -archs "$APP/Contents/MacOS/RadioAtlas")"
echo "    sha256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"

# Prove the zip round-trips: an archive that unpacks into a broken signature
# fails for every user and for nobody testing locally.
VERIFY=$(mktemp -d)
ditto -x -k "$ZIP" "$VERIFY"
codesign --verify --deep "$VERIFY/RadioAtlas.app"
echo "    signature survives the round trip: ok"
rm -rf "$VERIFY"
