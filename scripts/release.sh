#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: TEAM_ID=XXXXXXXXXX SPARKLE_PUBLIC_ED_KEY=... bash scripts/release.sh [--build-only]

Build, sign, notarize, and package InventoryWatch for direct distribution.

Environment:
  TEAM_ID              Required Apple Developer team ID.
  SPARKLE_PUBLIC_ED_KEY Required Sparkle EdDSA public key (base64).
  RELEASE_CHANNEL      stable or beta (default: stable).
  RELEASE_TAG          GitHub release tag (default: v<marketing version>).
  SIGNING_IDENTITY     Developer ID Application identity (default: Developer ID Application).
  NOTARY_PROFILE       notarytool Keychain profile (default: inventorywatch-notary).

--build-only creates and verifies a signed archive without contacting the
notary service. It does not create a distributable ZIP or appcast item.
EOF
}

BUILD_ONLY=false
case "${1:-}" in
    "") ;;
    --build-only) BUILD_ONLY=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 1 ;;
esac
if [[ $# -gt 1 ]]; then
    usage >&2
    exit 1
fi
if [[ -z "${TEAM_ID:-}" ]]; then
    echo "Error: TEAM_ID must be set to your Apple Developer team ID." >&2
    exit 1
fi
if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]] || ! printf '%s' "$SPARKLE_PUBLIC_ED_KEY" | grep -Eq '^[A-Za-z0-9+/]{43}=$'; then
    echo "Error: SPARKLE_PUBLIC_ED_KEY must be a base64-encoded Sparkle EdDSA public key." >&2
    exit 1
fi

RELEASE_CHANNEL="${RELEASE_CHANNEL:-stable}"
case "$RELEASE_CHANNEL" in
    stable|beta) ;;
    *) echo "Error: RELEASE_CHANNEL must be stable or beta." >&2; exit 1 ;;
esac

SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-inventorywatch-notary}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
if [[ "$BUILD_ONLY" == false ]]; then
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi

mkdir -p "$ROOT/build/release"
OUTPUT="$(mktemp -d "$ROOT/build/release/run.XXXXXX")"
trap 'echo "Error: release failed at line $LINENO. Retained output: $OUTPUT" >&2' ERR
ARCHIVE="$OUTPUT/InventoryWatch.xcarchive"
APP="$ARCHIVE/Products/Applications/InventoryWatch.app"
echo "Release output: $OUTPUT"

xcodebuild archive \
    -project "$ROOT/InventoryWatch.xcodeproj" \
    -scheme InventoryWatch \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    -derivedDataPath "$OUTPUT/DerivedData" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
    | tee "$OUTPUT/archive.log"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign --display --verbose=4 "$APP" 2>"$OUTPUT/signature.txt"
cat "$OUTPUT/signature.txt"
grep -q '^Authority=Developer ID Application:' "$OUTPUT/signature.txt"
grep -q "^TeamIdentifier=${TEAM_ID}$" "$OUTPUT/signature.txt"
grep -q 'flags=.*runtime' "$OUTPUT/signature.txt"
grep -q '^Timestamp=' "$OUTPUT/signature.txt"
lipo "$APP/Contents/MacOS/InventoryWatch" -verify_arch arm64
lipo "$APP/Contents/MacOS/InventoryWatch" -verify_arch x86_64

if [[ "$BUILD_ONLY" == true ]]; then
    echo "Signed archive verified: $ARCHIVE"
    echo "NOT notarized. Run without --build-only before distribution."
    exit 0
fi

SUBMISSION="$OUTPUT/notarization-upload.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$SUBMISSION"
if xcrun notarytool submit "$SUBMISSION" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format plist >"$OUTPUT/notarization.plist"; then
    SUBMIT_EXIT=0
else
    SUBMIT_EXIT=$?
fi
cat "$OUTPUT/notarization.plist"
if ! STATUS="$(plutil -extract status raw -o - "$OUTPUT/notarization.plist")"; then
    echo "Error: no notarization status returned (exit $SUBMIT_EXIT). See output above." >&2
    exit 1
fi
if [[ "$SUBMIT_EXIT" -ne 0 || "$STATUS" != Accepted ]]; then
    echo "Error: notarization did not succeed (status: $STATUS, exit: $SUBMIT_EXIT)." >&2
    if SUBMISSION_ID="$(plutil -extract id raw -o - "$OUTPUT/notarization.plist")"; then
        xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$NOTARY_PROFILE" "$OUTPUT/notarization-log.json"
    fi
    exit 1
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP"

RELEASE_ZIP="$OUTPUT/InventoryWatch.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$RELEASE_ZIP"
(cd "$OUTPUT" && shasum -a 256 InventoryWatch.zip >InventoryWatch.zip.sha256)

SIGN_UPDATE="$OUTPUT/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
if [[ ! -x "$SIGN_UPDATE" ]]; then
    echo "Error: Sparkle sign_update tool not found at $SIGN_UPDATE." >&2
    exit 1
fi
SIGNATURE_OUTPUT="$("$SIGN_UPDATE" "$RELEASE_ZIP")"
ED_SIGNATURE="$(printf '%s\n' "$SIGNATURE_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
if [[ -z "$ED_SIGNATURE" ]]; then
    echo "Error: could not read Sparkle signature from sign_update output." >&2
    printf '%s\n' "$SIGNATURE_OUTPUT" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"
if [[ ! "$RELEASE_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: RELEASE_TAG may only contain letters, numbers, dots, underscores, and hyphens." >&2
    exit 1
fi
ARCHIVE_LENGTH="$(stat -f%z "$RELEASE_ZIP")"
PUBLISHED_AT="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
APPCAST_ITEM="$OUTPUT/appcast-item.xml"

{
    printf '        <item>\n'
    printf '            <title>InventoryWatch %s</title>\n' "$VERSION"
    printf '            <sparkle:version>%s</sparkle:version>\n' "$BUILD_VERSION"
    printf '            <sparkle:shortVersionString>%s</sparkle:shortVersionString>\n' "$VERSION"
    if [[ "$RELEASE_CHANNEL" == beta ]]; then
        printf '            <sparkle:channel>beta</sparkle:channel>\n'
    fi
    printf '            <pubDate>%s</pubDate>\n' "$PUBLISHED_AT"
    printf '            <enclosure url="https://github.com/worthbak/inventory-checker-app/releases/download/%s/InventoryWatch.zip"\n' "$RELEASE_TAG"
    printf '                       sparkle:edSignature="%s" length="%s" type="application/octet-stream" />\n' "$ED_SIGNATURE" "$ARCHIVE_LENGTH"
    printf '        </item>\n'
} >"$APPCAST_ITEM"

echo "Notarized release ready: $RELEASE_ZIP"
echo "Sparkle appcast item ready: $APPCAST_ITEM"
echo "Upload InventoryWatch.zip to GitHub release $RELEASE_TAG, then add the generated item to docs/appcast.xml."
