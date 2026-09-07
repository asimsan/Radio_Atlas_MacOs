#!/bin/bash
# Packages the SwiftPM executable into RadioAtlas.app so it can be launched
# from Spotlight/Launchpad.
#
#   --install     also copy it to ~/Applications and register it
#   --universal   build for arm64 and x86_64, required for anything shipped to
#                 other people (a plain build only runs on this Mac's own
#                 architecture)
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
CONFIG="${CONFIG:-release}"
BUNDLE_ID="com.asimsan.RadioAtlas"
INSTALL_DIR="$HOME/Applications"

VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "0.1.0")

INSTALL=0
UNIVERSAL=0
for arg in "$@"; do
    case "$arg" in
        --install)   INSTALL=1 ;;
        --universal) UNIVERSAL=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

ARCH_ARGS=()
if [[ $UNIVERSAL -eq 1 ]]; then
    ARCH_ARGS=(--arch arm64 --arch x86_64)
fi

echo "==> Building ($CONFIG${ARCH_ARGS:+, universal})"
swift build -c "$CONFIG" "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}"
BIN_DIR=$(swift build -c "$CONFIG" "${ARCH_ARGS[@]+"${ARCH_ARGS[@]}"}" --show-bin-path)

APP="$ROOT/.build/RadioAtlas.app"
echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/RadioAtlas" "$APP/Contents/MacOS/RadioAtlas"

# Resources go in the standard Contents/Resources; CountryLookup checks the
# main bundle before falling back to Bundle.module. Copying SwiftPM's
# resource bundle to the .app root instead would satisfy Bundle.module but
# codesign rejects it there ("unsealed contents present in the bundle root").
# SwiftPM lays the resource bundle out differently per build: a shallow
# directory for a single architecture, a proper Contents/Resources bundle for
# a universal one. Locate the file rather than assuming either shape, and fail
# loudly -- a missing geojson renders the globe with no countries at all, with
# no other symptom.
GEOJSON=$(find "$BIN_DIR/RadioAtlas_RadioAtlasCore.bundle" -name countries-110m.geojson -print -quit)
if [[ -z "$GEOJSON" ]]; then
    echo "error: countries-110m.geojson not found in the built resource bundle" >&2
    exit 1
fi
cp "$GEOJSON" "$APP/Contents/Resources/"

echo "==> Generating icon"
# Compiled explicitly rather than run as `swift make-icon.swift`: inside a
# package directory that form resolves to a package run and launches the app
# itself, which never exits and hangs this script.
ICON_BUILD=$(mktemp -d)
cp "$ROOT/scripts/make-icon.swift" "$ICON_BUILD/main.swift"
swiftc -O "$ICON_BUILD/main.swift" -o "$ICON_BUILD/make-icon"
"$ICON_BUILD/make-icon" "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICON_BUILD"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>              <string>Radio Atlas</string>
    <key>CFBundleDisplayName</key>       <string>Radio Atlas</string>
    <key>CFBundleExecutable</key>        <string>RadioAtlas</string>
    <key>CFBundleIdentifier</key>        <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>       <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>           <string>$VERSION</string>
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>    <string>13.0</string>
    <key>NSHighResolutionCapable</key>   <true/>
    <!-- Menu bar app: no Dock icon, matching setActivationPolicy(.accessory).
         Spotlight and Launchpad still index and launch it. -->
    <key>LSUIElement</key>               <true/>
    <!-- 38% of the radio-browser directory's stream URLs are cleartext http,
         and App Transport Security blocks those outright once the binary is
         bundled -- which is why stations that played under 'swift run' stopped
         working in the packaged app. The exception is scoped to AVFoundation
         media rather than NSAllowsArbitraryLoads: the directory API is HTTPS
         and stays protected, and nothing else is fetched over the network. -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoadsForMedia</key> <true/>
    </dict>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Guard the ATS exception: without it the app silently cannot play the ~38%
# of stations served over cleartext http, with no error beyond a failed play.
if ! /usr/libexec/PlistBuddy -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoadsForMedia" \
     "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    echo "error: Info.plist is missing the ATS media exception" >&2
    exit 1
fi

# Ad-hoc signature so Launch Services and TCC treat this as a stable identity.
# The resource bundle is deliberately left unsigned: SwiftPM emits it as a
# shallow directory with no Info.plist, which codesign rejects as a bundle.
# It carries no executable code, so the outer signature sealing it is enough.
echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP"

if [[ $UNIVERSAL -eq 1 ]]; then
    # A one-architecture bundle silently fails to launch on the other kind of
    # Mac, so make a shipped build prove it is fat before it goes anywhere.
    archs=$(lipo -archs "$APP/Contents/MacOS/RadioAtlas")
    if [[ "$archs" != *arm64* || "$archs" != *x86_64* ]]; then
        echo "error: --universal asked for, but binary is: $archs" >&2
        exit 1
    fi
    echo "==> Architectures: $archs"
fi

if [[ $INSTALL -eq 1 ]]; then
    echo "==> Installing to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/RadioAtlas.app"
    cp -R "$APP" "$INSTALL_DIR/RadioAtlas.app"
    # Nudge Spotlight/Launch Services to index it immediately.
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -f "$INSTALL_DIR/RadioAtlas.app"
    echo "Installed: $INSTALL_DIR/RadioAtlas.app"
else
    echo "Built: $APP  (re-run with --install to copy to $INSTALL_DIR)"
fi
