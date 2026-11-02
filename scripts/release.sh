#!/usr/bin/env bash
# Builds, signs, notarizes and publishes a Keypad release (RFC-0004).
#
#   scripts/release.sh <version> [--dry-run]
#
# --dry-run stops after the notarized DMG is verified: no tag check, no GitHub Release, no tap change.
# Environment: TAP_DIR (default ../homebrew-tap), NOTARY_PROFILE (default keypad-notary), NOTES_FILE (optional).
set -euo pipefail

readonly TEAM_ID="4HYL3L2W4Z"
readonly TAP_DIR="${TAP_DIR:-../homebrew-tap}"
readonly NOTARY_PROFILE="${NOTARY_PROFILE:-keypad-notary}"
readonly OUT="build/release"

fail() {
  echo "release: $*" >&2
  exit 1
}

version="${1:-}"
dry_run=false
[[ "${2:-}" == "--dry-run" ]] && dry_run=true

cd "$(dirname "$0")/.."

# 1. Preflight: every check runs before anything is built.
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must look like 1.2.3, got '$version'"

marketing_versions=$(grep -o 'MARKETING_VERSION = [^;]*' Keypad.xcodeproj/project.pbxproj | sort -u | sed 's/MARKETING_VERSION = //')
[[ $marketing_versions == "$version" ]] || fail "MARKETING_VERSION is '$marketing_versions', expected $version"

if ! $dry_run; then
  [[ -z $(git status --porcelain --untracked-files=no) ]] || fail "tracked files have uncommitted changes"
  [[ $(git branch --show-current) == "main" ]] || fail "releases are cut from main"
  [[ $(git rev-parse -q --verify "refs/tags/v$version^{commit}" || true) == "$(git rev-parse HEAD)" ]] ||
    fail "tag v$version must exist and point at HEAD"
  gh auth status >/dev/null 2>&1 || fail "gh is not signed in"
  [[ -f "$TAP_DIR/Casks/keypad.rb" ]] || fail "no cask at $TAP_DIR/Casks/keypad.rb"
fi

identity=$(security find-identity -v -p codesigning | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" | head -1)
[[ -n $identity ]] || fail "no Developer ID Application certificate for team $TEAM_ID in the keychain"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
  fail "notary profile '$NOTARY_PROFILE' is missing; run: xcrun notarytool store-credentials $NOTARY_PROFILE --key <AuthKey.p8> --key-id <key id> --issuer <issuer id>"

# 2. Build: archive and export with Developer ID.
rm -rf "$OUT"
mkdir -p "$OUT"
echo "Archiving Keypad ${version}…"
xcodebuild archive -project Keypad.xcodeproj -scheme Keypad -configuration Release \
  -archivePath "$OUT/Keypad.xcarchive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$TEAM_ID" >"$OUT/archive.log" 2>&1 ||
  fail "archive failed; see $OUT/archive.log"
xcodebuild -exportArchive -archivePath "$OUT/Keypad.xcarchive" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$OUT/export" >"$OUT/export.log" 2>&1 ||
  fail "export failed; see $OUT/export.log"
app="$OUT/export/Keypad.app"

# 3. Check the app's signature.
codesign --verify --deep --strict "$app" || fail "the exported app's signature does not verify"
signature=$(codesign -dvv "$app" 2>&1)
grep -q "TeamIdentifier=$TEAM_ID" <<<"$signature" || fail "the app is not signed by team $TEAM_ID"
grep -q "runtime" <<<"$signature" || fail "the app is not signed with the Hardened Runtime"

# 4. DMG: the app and an Applications link, signed.
dmg="$OUT/Keypad-$version.dmg"
stage="$OUT/dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Keypad -srcfolder "$stage" -format UDZO "$dmg" >/dev/null || fail "hdiutil could not create the DMG"
codesign --sign "$identity" --timestamp "$dmg" || fail "could not sign the DMG"

# 5. Notarize, staple and let Gatekeeper judge the result.
echo "Notarizing (this can take a few minutes)…"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait | tee "$OUT/notarize.log"
grep -q "status: Accepted" "$OUT/notarize.log" || fail "notarization was not accepted; see $OUT/notarize.log"
xcrun stapler staple "$dmg" >/dev/null || fail "could not staple the ticket"
xcrun stapler validate "$dmg" >/dev/null || fail "the stapled ticket does not validate"
spctl --assess --type open --context context:primary-signature -v "$dmg" 2>&1 | grep -q accepted ||
  fail "Gatekeeper rejects the DMG"

# 6. Checksum.
sha256=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
echo "Verified: $dmg"
echo "SHA-256:  $sha256"
if $dry_run; then
  echo "Dry run: nothing was published."
  exit 0
fi

# 7. Publish the GitHub Release.
if [[ -n ${NOTES_FILE:-} ]]; then
  gh release create "v$version" "$dmg" --title "Keypad $version" --notes-file "$NOTES_FILE"
else
  gh release create "v$version" "$dmg" --title "Keypad $version" --generate-notes
fi

# 8. Update the cask in the tap and commit; pushing stays a separate, deliberate step.
cask="$TAP_DIR/Casks/keypad.rb"
sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 .*/  sha256 \"$sha256\"/" "$cask"
git -C "$TAP_DIR" add Casks/keypad.rb
git -C "$TAP_DIR" commit -m "keypad $version"
echo "Released Keypad $version. Push the tap with: git -C $TAP_DIR push"
