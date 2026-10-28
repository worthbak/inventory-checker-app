#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: SPARKLE_PUBLIC_ED_KEY=... bash scripts/release.sh [--build-only]

Test, build, sign, notarize, publish, and package InventoryWatch for direct distribution.

Environment:
  TEAM_ID              Apple Developer team ID (defaults to the Xcode project setting).
  SPARKLE_PUBLIC_ED_KEY Required Sparkle EdDSA public key (base64), or configure it in Xcode.
  RELEASE_CHANNEL      stable or beta (default: stable).
  RELEASE_TAG          GitHub release tag (default: v<marketing version>-build.<build number>).
  RELEASE_REPOSITORY   GitHub repository (default: drallgood/inventory-checker-app).
  RELEASE_REMOTE       Git remote matching RELEASE_REPOSITORY (detected automatically).
  RELEASE_BRANCH       Branch to publish from (default: main).
  SIGNING_IDENTITY     Developer ID Application identity (default: Developer ID Application).
  NOTARY_PROFILE       notarytool Keychain profile (default: inventorywatch-notary).

--build-only runs tests and creates a signed archive without contacting the
notary service or publishing a GitHub release.
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
RELEASE_CHANNEL="${RELEASE_CHANNEL:-stable}"
case "$RELEASE_CHANNEL" in
    stable|beta) ;;
    *) echo "Error: RELEASE_CHANNEL must be stable or beta." >&2; exit 1 ;;
esac

SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-inventorywatch-notary}"
RELEASE_REPOSITORY="${RELEASE_REPOSITORY:-drallgood/inventory-checker-app}"
RELEASE_REMOTE="${RELEASE_REMOTE:-}"
RELEASE_BRANCH="${RELEASE_BRANCH:-main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for command in xcodebuild xcrun codesign lipo spctl python3; do
    command -v "$command" >/dev/null || {
        echo "Error: required command not found: $command." >&2
        exit 1
    }
done

RELEASE_SETTINGS="$(xcodebuild -project "$ROOT/InventoryWatch.xcodeproj" \
    -target InventoryWatch -configuration Release -showBuildSettings 2>/dev/null)"
if [[ -z "${TEAM_ID:-}" ]]; then
    TEAM_ID="$(printf '%s\n' "$RELEASE_SETTINGS" |
        sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = //p' | sort -u)"
fi
if [[ -z "$TEAM_ID" || "$TEAM_ID" == *$'\n'* ]]; then
    echo "Error: set TEAM_ID or configure one unambiguous DEVELOPMENT_TEAM in Xcode." >&2
    exit 1
fi
if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
    SPARKLE_PUBLIC_ED_KEY="$(printf '%s\n' "$RELEASE_SETTINGS" |
        sed -n 's/^[[:space:]]*SPARKLE_PUBLIC_ED_KEY = //p' | sort -u)"
fi
if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]] || ! printf '%s' "$SPARKLE_PUBLIC_ED_KEY" | grep -Eq '^[A-Za-z0-9+/]{43}=$'; then
    echo "Error: configure SPARKLE_PUBLIC_ED_KEY in Xcode or provide its base64 value in the environment." >&2
    exit 1
fi

xcrun --find notarytool >/dev/null
xcrun --find stapler >/dev/null
if [[ "$BUILD_ONLY" == false ]]; then
    for command in gh git; do
        command -v "$command" >/dev/null || {
            echo "Error: required publishing command not found: $command." >&2
            exit 1
        }
    done
    gh auth status --hostname github.com
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Error: release from a clean worktree; commit or stash all changes first." >&2
        exit 1
    fi
    CURRENT_BRANCH="$(git branch --show-current)"
    if [[ "$CURRENT_BRANCH" != "$RELEASE_BRANCH" ]]; then
        echo "Error: release from '$RELEASE_BRANCH', not '$CURRENT_BRANCH'." >&2
        exit 1
    fi
    if [[ -z "$RELEASE_REMOTE" ]]; then
        for candidate_remote in $(git remote); do
            candidate_repository="$(git remote get-url "$candidate_remote" |
                sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
            if [[ "$candidate_repository" == "$RELEASE_REPOSITORY" ]]; then
                RELEASE_REMOTE="$candidate_remote"
                break
            fi
        done
    fi
    if [[ -z "$RELEASE_REMOTE" ]]; then
        echo "Error: no Git remote points to '$RELEASE_REPOSITORY'; set RELEASE_REMOTE." >&2
        exit 1
    fi
    git remote get-url "$RELEASE_REMOTE" >/dev/null
    REMOTE_REPOSITORY="$(git remote get-url "$RELEASE_REMOTE" |
        sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
    if [[ "$REMOTE_REPOSITORY" != "$RELEASE_REPOSITORY" ]]; then
        echo "Error: push remote '$RELEASE_REMOTE' points to '$REMOTE_REPOSITORY', not '$RELEASE_REPOSITORY'." >&2
        exit 1
    fi
    PUSH_URLS="$(git remote get-url --push --all "$RELEASE_REMOTE")"
    if [[ -z "$PUSH_URLS" ]]; then
        echo "Error: remote '$RELEASE_REMOTE' has no push URL." >&2
        exit 1
    fi
    while IFS= read -r push_url; do
        PUSH_REPOSITORY="$(printf '%s\n' "$push_url" |
            sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
        if [[ "$PUSH_REPOSITORY" != "$RELEASE_REPOSITORY" ]]; then
            echo "Error: push URL '$push_url' points to '$PUSH_REPOSITORY', not '$RELEASE_REPOSITORY'." >&2
            exit 1
        fi
    done <<< "$PUSH_URLS"
    if [[ "$(gh repo view "$RELEASE_REPOSITORY" --json nameWithOwner --jq .nameWithOwner)" != "$RELEASE_REPOSITORY" ]]; then
        echo "Error: GitHub repository lookup did not match '$RELEASE_REPOSITORY'." >&2
        exit 1
    fi
    git fetch "$RELEASE_REMOTE" "$RELEASE_BRANCH"
    if [[ "$(git rev-list --left-right --count "HEAD...$RELEASE_REMOTE/$RELEASE_BRANCH")" != $'0\t0' ]]; then
        echo "Error: '$RELEASE_BRANCH' must match '$RELEASE_REMOTE/$RELEASE_BRANCH' before release." >&2
        exit 1
    fi
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi

CURRENT_BUILD_VERSION="$(xcrun agvtool what-version -terse)"
if [[ ! "$CURRENT_BUILD_VERSION" =~ ^[0-9]+$ ]]; then
    echo "Error: current build number must be an integer (got: $CURRENT_BUILD_VERSION)." >&2
    exit 1
fi
NEXT_BUILD_VERSION="$((CURRENT_BUILD_VERSION + 1))"
VERSION="$(printf '%s\n' "$RELEASE_SETTINGS" |
    sed -n 's/^[[:space:]]*MARKETING_VERSION = //p' | sort -u)"
if [[ -z "$VERSION" || "$VERSION" == *$'\n'* ]]; then
    echo "Error: could not determine one marketing version from the InventoryWatch target." >&2
    exit 1
fi
if [[ "$BUILD_ONLY" == true ]]; then
    RELEASE_TAG="${RELEASE_TAG:-v${VERSION}-build.${CURRENT_BUILD_VERSION}}"
else
    RELEASE_TAG="${RELEASE_TAG:-v${VERSION}-build.${NEXT_BUILD_VERSION}}"
fi
if [[ ! "$RELEASE_TAG" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: RELEASE_TAG may only contain letters, numbers, dots, underscores, and hyphens." >&2
    exit 1
fi
if [[ "$BUILD_ONLY" == false ]] && gh release view "$RELEASE_TAG" --repo "$RELEASE_REPOSITORY" >/dev/null 2>&1; then
    echo "Error: release '$RELEASE_TAG' already exists in $RELEASE_REPOSITORY." >&2
    exit 1
fi
if [[ "$BUILD_ONLY" == false ]] &&
    { git show-ref --verify --quiet "refs/tags/$RELEASE_TAG" ||
      git ls-remote --exit-code "$RELEASE_REMOTE" \
          "refs/tags/$RELEASE_TAG" "refs/tags/$RELEASE_TAG^{}" >/dev/null 2>&1; }; then
    echo "Error: tag '$RELEASE_TAG' already exists; choose a new RELEASE_TAG." >&2
    exit 1
fi

mkdir -p "$ROOT/build/release"
OUTPUT="$(mktemp -d "$ROOT/build/release/run.XXXXXX")"
trap 'echo "Error: release failed at line $LINENO. Retained output: $OUTPUT" >&2' ERR
ARCHIVE="$OUTPUT/InventoryWatch.xcarchive"
APP="$ARCHIVE/Products/Applications/InventoryWatch.app"
echo "Release output: $OUTPUT"

if ! python3 -c 'import markdown' >/dev/null 2>&1; then
    echo "Error: release notes require Markdown. Install with: python3 -m pip install -r scripts/requirements-release.txt" >&2
    exit 1
fi
python3 "$ROOT/scripts/release_notes.py" "$ROOT/CHANGELOG.md" "$VERSION" "$OUTPUT/release-notes.xml"

xcodebuild test \
    -project "$ROOT/InventoryWatch.xcodeproj" \
    -scheme InventoryWatch \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$OUTPUT/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
    | tee "$OUTPUT/test.log"

if [[ "$BUILD_ONLY" == true ]]; then
    BUILD_VERSION="$CURRENT_BUILD_VERSION"
else
    BUILD_VERSION="$NEXT_BUILD_VERSION"
fi
echo "Release build number: $BUILD_VERSION"

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
    CURRENT_PROJECT_VERSION="$BUILD_VERSION" \
    SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
    | tee "$OUTPUT/archive.log"

SPARKLE_FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/B"
SPARKLE_CHECKOUT="$OUTPUT/DerivedData/SourcePackages/checkouts/Sparkle"
APP_ENTITLEMENTS="$OUTPUT/app-entitlements.plist"
codesign -d --entitlements :- "$APP" >"$APP_ENTITLEMENTS"

verify_release_signature() {
    local component="$1"
    codesign --display --verbose=4 "$component" 2>"$OUTPUT/component-signature.txt"
    grep -q "^TeamIdentifier=${TEAM_ID}$" "$OUTPUT/component-signature.txt"
    grep -q '^Timestamp=' "$OUTPUT/component-signature.txt"
}

for helper_bundle in "$SPARKLE_VERSION/Updater.app" "$SPARKLE_VERSION"/XPCServices/*.xpc; do
    [[ -d "$helper_bundle" ]] || continue
    HELPER_SIGN_ARGS=(--force --options runtime --timestamp)
    if [[ "$(basename "$helper_bundle")" == "Downloader.xpc" ]]; then
        DOWNLOADER_ENTITLEMENTS="$SPARKLE_CHECKOUT/Downloader/Downloader.entitlements"
        if [[ ! -f "$DOWNLOADER_ENTITLEMENTS" ]]; then
            echo "Error: Sparkle Downloader entitlements not found at $DOWNLOADER_ENTITLEMENTS." >&2
            exit 1
        fi
        HELPER_SIGN_ARGS+=(--entitlements "$DOWNLOADER_ENTITLEMENTS")
    fi
    codesign "${HELPER_SIGN_ARGS[@]}" \
        --sign "$SIGNING_IDENTITY" "$helper_bundle"
    verify_release_signature "$helper_bundle"
done

AUTOUPDATE_IDENTIFIER="$(codesign --display --verbose=4 "$SPARKLE_VERSION/Autoupdate" 2>&1 |
    sed -n 's/^Identifier=//p')"
if [[ -z "$AUTOUPDATE_IDENTIFIER" ]]; then
    echo "Error: could not determine Sparkle Autoupdate's existing code identifier." >&2
    exit 1
fi
codesign --force --options runtime --timestamp --identifier "$AUTOUPDATE_IDENTIFIER" \
    --sign "$SIGNING_IDENTITY" "$SPARKLE_VERSION/Autoupdate"
verify_release_signature "$SPARKLE_VERSION/Autoupdate"
codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" "$SPARKLE_FRAMEWORK"
verify_release_signature "$SPARKLE_FRAMEWORK"
codesign --force --options runtime --timestamp \
    --entitlements "$APP_ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" "$APP"
verify_release_signature "$APP"

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
        NOTARIZATION_LOG="$OUTPUT/notarization-log.json"
        if xcrun notarytool log "$SUBMISSION_ID" \
            --keychain-profile "$NOTARY_PROFILE" "$NOTARIZATION_LOG"; then
            python3 - "$NOTARIZATION_LOG" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as log_file:
    report = json.load(log_file)
for issue in report.get("issues") or []:
    print(
        f"{issue.get('severity', 'unknown')}: "
        f"{issue.get('path', 'unknown path')}: "
        f"{issue.get('message', 'no details')}",
        file=sys.stderr,
    )
PY
            echo "Full notarization log: $NOTARIZATION_LOG" >&2
        fi
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

ARCHIVED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [[ "$ARCHIVED_VERSION" != "$VERSION" ]]; then
    echo "Error: archived marketing version $ARCHIVED_VERSION does not match project version $VERSION." >&2
    exit 1
fi
ARCHIVED_BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
if [[ "$ARCHIVED_BUILD_VERSION" != "$BUILD_VERSION" ]]; then
    echo "Error: archived build number $ARCHIVED_BUILD_VERSION does not match incremented build number $BUILD_VERSION." >&2
    exit 1
fi
MINIMUM_SYSTEM_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")"
ARCHIVE_LENGTH="$(stat -f%z "$RELEASE_ZIP")"
PUBLISHED_AT="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
APPCAST_ITEM="$OUTPUT/appcast-item.xml"

{
    printf '        <item>\n'
    printf '            <title>InventoryWatch %s</title>\n' "$VERSION"
    printf '            <sparkle:version>%s</sparkle:version>\n' "$BUILD_VERSION"
    printf '            <sparkle:shortVersionString>%s</sparkle:shortVersionString>\n' "$VERSION"
    printf '            <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>\n' "$MINIMUM_SYSTEM_VERSION"
    if [[ "$RELEASE_CHANNEL" == beta ]]; then
        printf '            <sparkle:channel>beta</sparkle:channel>\n'
    fi
    printf '            <pubDate>%s</pubDate>\n' "$PUBLISHED_AT"
    cat "$OUTPUT/release-notes.xml"
    printf '            <enclosure url="https://github.com/%s/releases/download/%s/InventoryWatch.zip"\n' "$RELEASE_REPOSITORY" "$RELEASE_TAG"
    printf '                       sparkle:edSignature="%s" length="%s" type="application/octet-stream" />\n' "$ED_SIGNATURE" "$ARCHIVE_LENGTH"
    printf '        </item>\n'
} >"$APPCAST_ITEM"

if [[ "$BUILD_ONLY" == false ]]; then
    xcrun agvtool -noscm new-version "$BUILD_VERSION"
    if [[ "$(xcrun agvtool what-version -terse)" != "$BUILD_VERSION" ]]; then
        echo "Error: could not persist build number $BUILD_VERSION in the Xcode project." >&2
        exit 1
    fi
fi

git add InventoryWatch.xcodeproj/project.pbxproj
git commit -m "Bump release build number to $BUILD_VERSION" \
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
RELEASE_COMMIT="$(git rev-parse HEAD)"
git push "$RELEASE_REMOTE" "$RELEASE_BRANCH"

GH_RELEASE_ARGS=(
    release create "$RELEASE_TAG"
    "$RELEASE_ZIP"
    "$OUTPUT/InventoryWatch.zip.sha256"
    --repo "$RELEASE_REPOSITORY"
    --target "$RELEASE_COMMIT"
    --title "InventoryWatch $VERSION (build $BUILD_VERSION)"
    --generate-notes
)
if [[ "$RELEASE_CHANNEL" == beta ]]; then
    GH_RELEASE_ARGS+=(--prerelease)
fi
gh "${GH_RELEASE_ARGS[@]}"

python3 - "$ROOT/docs/appcast.xml" "$APPCAST_ITEM" "$BUILD_VERSION" <<'PY'
from pathlib import Path
import sys
import re
import xml.etree.ElementTree as ET

feed_path = Path(sys.argv[1])
item_path = Path(sys.argv[2])
build_version = sys.argv[3]
feed = feed_path.read_text()
root = ET.fromstring(feed)
channel = root.find("channel")
if channel is None:
    raise SystemExit("Appcast has no channel element.")
sparkle_version = "{http://www.andymatuschak.org/xml-namespaces/sparkle}version"
if any(item.findtext(sparkle_version) == build_version for item in channel.findall("item")):
    raise SystemExit(f"Appcast already contains build {build_version}.")
first_item = re.search(r"(?m)^[ \t]*<item(?:\s|>)", feed)
if first_item is not None:
    position = first_item.start()
else:
    closing_tag = "</channel>"
    position = feed.rfind(closing_tag)
    if position < 0:
        raise SystemExit("Appcast has no closing </channel> element.")
item = item_path.read_text().rstrip()
updated_feed = f"{feed[:position]}{item}\n{feed[position:]}"
ET.fromstring(updated_feed)
feed_path.write_text(updated_feed)
PY

git add docs/appcast.xml
git commit -m "Publish InventoryWatch $VERSION build $BUILD_VERSION to appcast" \
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push "$RELEASE_REMOTE" "$RELEASE_BRANCH"

echo "Release published: https://github.com/$RELEASE_REPOSITORY/releases/tag/$RELEASE_TAG"
PAGES_OWNER="${RELEASE_REPOSITORY%%/*}"
PAGES_REPOSITORY="${RELEASE_REPOSITORY#*/}"
echo "Sparkle feed published: https://$PAGES_OWNER.github.io/$PAGES_REPOSITORY/appcast.xml"
