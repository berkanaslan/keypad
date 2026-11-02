#!/usr/bin/env bash
# Builds, signs, notarizes and publishes a Keypad release (RFC-0004).
#
#   scripts/release.sh <version> [--dry-run | --tap-only]
#
# The build always uses committed source: the tag v<version>, or HEAD for a dry run.
# --dry-run stops after the notarized DMG is verified: no GitHub Release, no tap change.
# --tap-only skips the build and points the cask at the DMG already published for <version>.
# Environment: TAP_DIR (default ../homebrew-tap), NOTARY_PROFILE (default keypad-notary), NOTES_FILE (optional).
set -euo pipefail

readonly TEAM_ID="4HYL3L2W4Z"
readonly TAP_DIR="${TAP_DIR:-../homebrew-tap}"
readonly NOTARY_PROFILE="${NOTARY_PROFILE:-keypad-notary}"
readonly OUT="build/release"
readonly USAGE="usage: scripts/release.sh <version> [--dry-run | --tap-only]"

fail() {
  echo "release: $*" >&2
  exit 1
}

published=false
trap 'if (($? != 0)) && $published; then echo "release: v$version is public; finish with: scripts/release.sh $version --tap-only" >&2; fi' EXIT

(($# == 1 || $# == 2)) || fail "$USAGE"
version="$1"
case "${2:-}" in
  "") mode=release ;;
  --dry-run) mode=dry-run ;;
  --tap-only) mode=tap-only ;;
  *) fail "unknown option '$2'; $USAGE" ;;
esac

cd "$(dirname "$0")/.."
cask="$TAP_DIR/Casks/keypad.rb"
dmg_name="Keypad-$version.dmg"

# Stapled, notarized and signed by our team: what Gatekeeper and users will see.
verify_dmg() {
  local dmg="$1" signature assessment
  signature=$(codesign -dvv "$dmg" 2>&1) || fail "$dmg is not signed: $signature"
  grep -q "TeamIdentifier=$TEAM_ID" <<<"$signature" || fail "$dmg is not signed by team $TEAM_ID"
  xcrun stapler validate "$dmg" >/dev/null || fail "the stapled ticket of $dmg does not validate"
  assessment=$(spctl --assess --type open --context context:primary-signature -v "$dmg" 2>&1) ||
    fail "Gatekeeper rejects $dmg: $assessment"
  grep -q "source=Notarized Developer ID" <<<"$assessment" || fail "Gatekeeper does not see a notarized DMG: $assessment"
}

# Points the cask at the DMG published on GitHub, hashing the uploaded file itself.
update_tap() {
  local built_sha256="$1" download="$OUT/published" sha256
  [[ $(gh release view "v$version" --json isDraft,isPrerelease --jq '.isDraft or .isPrerelease') == "false" ]] ||
    fail "release v$version is a draft or a prerelease"
  rm -rf "$download"
  mkdir -p "$download"
  gh release download "v$version" --pattern "$dmg_name" --dir "$download" || fail "could not download $dmg_name from the release"
  verify_dmg "$download/$dmg_name"
  sha256=$(shasum -a 256 "$download/$dmg_name" | cut -d' ' -f1)
  [[ -z $built_sha256 || $sha256 == "$built_sha256" ]] || fail "the published $dmg_name differs from the one built here"

  /usr/bin/sed -i '' -E "s/^  version \".*\"/  version \"$version\"/; s/^  sha256 .*/  sha256 \"$sha256\"/" "$cask"
  if ! grep -qx "  version \"$version\"" "$cask" || ! grep -qx "  sha256 \"$sha256\"" "$cask"; then
    git -C "$TAP_DIR" checkout -- Casks/keypad.rb
    fail "could not set the version and sha256 lines in $cask"
  fi
  if git -C "$TAP_DIR" diff --quiet -- Casks/keypad.rb; then
    echo "The cask already points at Keypad $version."
  else
    git -C "$TAP_DIR" commit --quiet -m "keypad $version" -- Casks/keypad.rb
    echo "Updated the cask to Keypad $version. Push the tap with: git -C $TAP_DIR push"
  fi
}

# 1. Preflight: every check runs before anything is built or published.
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must look like 1.2.3, got '$version'"

if [[ $mode != dry-run ]]; then
  gh auth status >/dev/null 2>&1 || fail "gh is not signed in"
  [[ -f $cask ]] || fail "no cask at $cask"
  [[ $(git -C "$TAP_DIR" branch --show-current) == "main" ]] || fail "the tap is not on main"
  [[ -z $(git -C "$TAP_DIR" status --porcelain) ]] || fail "the tap has uncommitted changes"
fi

if [[ $mode == tap-only ]]; then
  gh release view "v$version" >/dev/null 2>&1 || fail "there is no release v$version to point the cask at"
  update_tap ""
  exit 0
fi

if [[ $mode == release ]]; then
  [[ -z $(git status --porcelain --untracked-files=no) ]] || fail "tracked files have uncommitted changes"
  [[ $(git branch --show-current) == "main" ]] || fail "releases are cut from main"
  [[ $(git rev-parse -q --verify "refs/tags/v$version^{commit}" || true) == "$(git rev-parse HEAD)" ]] ||
    fail "tag v$version must exist and point at HEAD"
  remote_tag=$(gh api "repos/{owner}/{repo}/git/ref/tags/v$version" --jq .object.sha 2>/dev/null) ||
    fail "tag v$version is not on GitHub; push it first: git push origin v$version"
  [[ $remote_tag == "$(git rev-parse "refs/tags/v$version")" ]] || fail "tag v$version on GitHub is not the local one"
  [[ $(gh api "repos/{owner}/{repo}/compare/main...v$version" --jq .status) =~ ^(identical|behind)$ ]] ||
    fail "tag v$version is not on main on GitHub; push main first"
  if gh release view "v$version" >/dev/null 2>&1; then
    fail "release v$version already exists; to update the tap only, run: scripts/release.sh $version --tap-only"
  fi
  [[ -z ${NOTES_FILE:-} || -f $NOTES_FILE ]] || fail "no notes file at $NOTES_FILE"
  source_ref="refs/tags/v$version"
else
  source_ref="HEAD"
fi

marketing_versions=$(git show "$source_ref:Keypad.xcodeproj/project.pbxproj" | grep -o 'MARKETING_VERSION = [^;]*' |
  sort -u | sed 's/MARKETING_VERSION = //') || fail "could not read MARKETING_VERSION at $source_ref"
[[ $marketing_versions == "$version" ]] || fail "MARKETING_VERSION is '$marketing_versions', expected $version"

identity=$(security find-identity -v -p codesigning | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" | head -1) || true
[[ -n $identity ]] || fail "no Developer ID Application certificate for team $TEAM_ID in the keychain"

xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 ||
  fail "notary profile '$NOTARY_PROFILE' is missing; run: xcrun notarytool store-credentials $NOTARY_PROFILE --key <AuthKey.p8> --key-id <key id> --issuer <issuer id>"

# 2. Build: archive the committed source and export it with Developer ID.
rm -rf "$OUT"
mkdir -p "$OUT/source"
git archive "$source_ref" | tar -x -C "$OUT/source" || fail "could not export $source_ref"
echo "Archiving Keypad ${version} from ${source_ref}…"
xcodebuild archive -project "$OUT/source/Keypad.xcodeproj" -scheme Keypad -configuration Release \
  -archivePath "$OUT/Keypad.xcarchive" -derivedDataPath "$OUT/DerivedData" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$TEAM_ID" >"$OUT/archive.log" 2>&1 ||
  fail "archive failed; see $OUT/archive.log"
xcodebuild -exportArchive -archivePath "$OUT/Keypad.xcarchive" \
  -exportOptionsPlist "$OUT/source/scripts/ExportOptions.plist" -exportPath "$OUT/export" >"$OUT/export.log" 2>&1 ||
  fail "export failed; see $OUT/export.log"
app="$OUT/export/Keypad.app"

# 3. Check the app's signature.
codesign --verify --deep --strict "$app" || fail "the exported app's signature does not verify"
signature=$(codesign -dvv "$app" 2>&1)
grep -q "TeamIdentifier=$TEAM_ID" <<<"$signature" || fail "the app is not signed by team $TEAM_ID"
grep -q "runtime" <<<"$signature" || fail "the app is not signed with the Hardened Runtime"

# 4. DMG: the app and an Applications link, signed.
dmg="$OUT/$dmg_name"
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
verify_dmg "$dmg"

# 6. Checksum.
sha256=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
echo "Verified: $dmg"
echo "SHA-256:  $sha256"
if [[ $mode == dry-run ]]; then
  echo "Dry run: nothing was published."
  exit 0
fi

# 7. Publish the GitHub Release, then update the cask; pushing the tap stays a separate, deliberate step.
if [[ -n ${NOTES_FILE:-} ]]; then
  gh release create "v$version" "$dmg" --verify-tag --title "Keypad $version" --notes-file "$NOTES_FILE"
else
  gh release create "v$version" "$dmg" --verify-tag --title "Keypad $version" --generate-notes
fi
published=true
update_tap "$sha256"
