# RFC-0004 Open Source Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keypad `v0.1.0` installs and opens on a clean Mac with `brew install --cask berkanaslan/tap/keypad`, from a public, MIT-licensed repository whose files and history hold no personal details.

**Architecture:**
- **No app logic changes.** This plan touches project rules, licence, icon assets, the README, a release script, a new tap repository, and the git history.
- **People:** tasks marked **(controller + PM)** need the PM's accounts, credentials, approval or a real trackpad. The others an implementer can do alone.

**Tech Stack:** Markdown, Bash, `xcodebuild` archive and export, `hdiutil`, `codesign`, `xcrun notarytool`, `xcrun stapler`, `spctl`, `qlmanage` and `sips` (icon rendering), `gh`, Homebrew casks (Ruby DSL), `git filter-repo`, `gitleaks`.

**Spec:** `docs/rfcs/0004-open-source-release.md` (amends `docs/rfcs/0000-vision-and-architecture.md` and `AGENTS.md`)

## Global Constraints

- **Git:**
  - Branch `feature/open-source-release` from `develop`; merge with `--no-ff`. A release merges `develop` into `main` with `--no-ff` and tags `vX.Y.Z`.
  - Conventional Commits; stage by path.
  - **From Task 1 on, commits use `42192003+berkanaslan@users.noreply.github.com`** (repo-local config, never committed).
  - Never push, force-push, create a GitHub repository or change visibility without the PM's explicit OK for that action.
- **Licence:** MIT, `Copyright (c) 2026 Berkan Aslan`. `Info.plist` copyright: `© 2026 Berkan Aslan. MIT License.`
- **Signing:**
  - Releases use a Developer ID Application certificate of team `4HYL3L2W4Z`, with the Hardened Runtime (already `YES` in the project) and a secure timestamp. The App Sandbox stays.
  - Local builds keep Apple Development (AGENTS.md §7).
  - Credentials never enter the repository or CI. The notarization keychain profile is named `keypad-notary`.
- **Artifacts:**
  - The DMG is `Keypad-<version>.dmg`, holding `Keypad.app` and an `Applications` link.
  - The release URL is `https://github.com/berkanaslan/keypad/releases/download/v<version>/Keypad-<version>.dmg`.
- **Tap:** repository `berkanaslan/homebrew-tap`, cask `Casks/keypad.rb`, exactly the cask in RFC-0004 §4.
- **Icon:**
  - The Aluminum artboard from the "Keypad App Icon" canvas (`project/Main.dc.html`) with accent `#0A84FF`, skin `#F2B18F` and separator `,`.
  - The ten macOS PNG sizes: 16, 32, 128, 256 and 512 pt at 1× and 2×.
- **Privacy:**
  - No email address, local path, company name or credential in any file or commit.
  - Allowed: the owner's name, team ID `4HYL3L2W4Z`, the bundle identifier, and `noreply@anthropic.com` in `Co-Authored-By` trailers.
- **Commands:** lint, tests and the signed build with its team check from AGENTS.md §10 stay green after every task that touches the project.

## Review Focus

1. **A release that Gatekeeper rejects.** The script must stop before uploading unless notarization, stapling and `spctl` all pass — Task 4's preflight and verification steps, and the dry run in Task 6.
2. **A personal detail survives into the public history.** Check every branch and tag, the commit metadata and the file content — the post-rewrite scan in Task 8.
3. **The cask points at a file that doesn't exist or doesn't match.** The version and SHA-256 must come from the uploaded DMG in the same run — Task 4's tap update and Task 9's install check.
4. **The app's version disagrees with the tag.** `MARKETING_VERSION` must equal the release version — Task 4's preflight.
5. **A broken first impression.** The README's install command must work exactly as written, and the README must not show an image that isn't there — Tasks 3, 7 and 9.

---

### Task 1: Project rules for open source

**Files:**
- Create: `LICENSE`
- Modify:
  - `AGENTS.md` (§1, §4, §7, §10);
  - `docs/rfcs/0000-vision-and-architecture.md` (G8, §4, §6, §11, §13, per the RFC-0004 amendments table);
  - `Keypad.xcodeproj/project.pbxproj` (`INFOPLIST_KEY_NSHumanReadableCopyright`, both configurations).

**Steps:**
- [ ] Set the repo-local identity: `git config user.email 42192003+berkanaslan@users.noreply.github.com`, keeping `user.name` "Berkan Aslan".
- [ ] Write `LICENSE` with the standard MIT text and `Copyright (c) 2026 Berkan Aslan`.
- [ ] Apply every row of RFC-0004's amendments table to RFC-0000 and AGENTS.md, in their existing style.
  - **AGENTS.md §4:** commits use the GitHub no-reply address, and the personal-data rule still lists what is allowed.
  - **AGENTS.md §7:** Developer ID for releases. Remove the paragraph about the owner's account not yet being in Xcode; keep the local Apple Development override.
  - **AGENTS.md §10:** add the release command `scripts/release.sh <version>` and its `--dry-run`.
- [ ] Change the copyright string in both build configurations.
- [ ] **Verify:**
  - `grep -rn "All rights reserved\|Mac App Store\|one-time paid" AGENTS.md docs/rfcs/0000-vision-and-architecture.md Keypad.xcodeproj` shows only historical mentions (RFC-0000's decision log and the amendment rows).
  - The signed build passes and the team check prints `TeamIdentifier=4HYL3L2W4Z`.
- [ ] **Commit:** `docs: adopt the MIT licence and the open source rules`

### Task 2: App icon

**Files:**
- Create:
  - `docs/assets/icon.svg`, the source with defaults filled in;
  - `Tools/AppIcon/render.sh`;
  - `docs/assets/icon-256.png`.
- Modify: `Keypad/Resources/Assets.xcassets/AppIcon.appiconset/` (ten PNGs and `Contents.json` with `filename` entries).

**Steps:**
- [ ] Turn the canvas's `project/Main.dc.html` `<svg>` into `docs/assets/icon.svg`:
  - Substitute `{{size}}` 1024, `{{accent}}` `#0A84FF`, `{{skin}}` `#F2B18F` and `{{sep}}` `,`.
  - Add `xmlns="http://www.w3.org/2000/svg"`.
  - Keep `font-family="-apple-system, 'SF Pro Display', 'Helvetica Neue', sans-serif"` on the numeral group.

  The controller saved a copy of the canvas file in the session scratchpad; if it is missing, read it again from the canvas.
- [ ] Write `Tools/AppIcon/render.sh <svg> <appiconset-dir> <readme-png>`:
  1. Render 1024 px with `qlmanage -t -s 1024 -o "$tmp" "$svg"`.
  2. Make each size with `sips -z <px> <px>`: 16, 32, 32, 64, 128, 256, 256, 512, 512, 1024.
  3. Name them `icon_<pt>x<pt>[@2x].png`.
  4. Write the 256 px README image.
- [ ] Run it, and update `Contents.json` so every one of the ten entries names its file.
- [ ] **Verify:**
  - `sips -g pixelWidth -g pixelHeight` matches every file.
  - The signed build passes, and `Assets.car` in the built app contains `AppIcon`: `assetutil --info … | grep -c AppIcon` is at least 1.
- [ ] **Commit:** `feat(app): ship the Aluminum app icon`

### Task 3: README as the product page

**Files:**
- Modify: `README.md`, a complete rewrite.

**Steps:**
- [ ] Write the README with RFC-0004 §6's sections, in order.
  - **Header:** `<p align="center"><img src="docs/assets/icon-256.png" width="128" alt="Keypad icon"></p>`, the name, a one-line pitch ("Turn your Mac's trackpad into a numeric keypad."), and badges from shields.io: latest release, macOS 26+, MIT, Homebrew.
  - **Install:**
    - `brew install --cask berkanaslan/tap/keypad`, exactly this string;
    - the DMG link `https://github.com/berkanaslan/keypad/releases/latest`;
    - the Accessibility explanation and the System Settings path (Privacy & Security › Accessibility).
  - **Use:**
    - ⌃⌥K;
    - tap the numbers;
    - the commit-key table from RFC-0000 §8.3;
    - Esc;
    - "Stay open after typing";
    - Settings (shortcut, active area, feedback).
  - **Privacy:** no network access, no analytics, no data leaves the Mac. The App Sandbox is on.
  - **FAQ:**
    - Accessibility;
    - password fields (Keypad shows a notice and doesn't open);
    - Spotlight and Mission Control (the numpad stays open);
    - why not the App Store (Guideline 2.4.5).
  - **Build from source:**
    - requirements: Xcode 27, macOS 26;
    - the clone, `swift test` and `xcodebuild` commands from AGENTS.md §10.
  - **Contributing:** AGENTS.md and the RFC process.
  - **Licence:** MIT.
- [ ] **No demo image yet.** Task 7 adds it, so the README never shows a missing image.
- [ ] **Verify:** every relative link and image path in the README exists: `grep -o '](\([^)h][^)]*\))' README.md`, then check each path.
- [ ] **Commit:** `docs: turn the README into the product page`

### Task 4: Release script

**Files:**
- Create: `scripts/release.sh`, `scripts/ExportOptions.plist`

**Interfaces:**
- Produces: `scripts/release.sh <version> [--dry-run]`.
  - **Environment:**
    - `TAP_DIR` defaults to `../homebrew-tap`;
    - `NOTARY_PROFILE` defaults to `keypad-notary`;
    - `NOTES_FILE` is optional and holds the release notes.
  - **Exit status:** non-zero and a one-line reason on any failed check.
  - **`--dry-run`:** does everything up to and including verification, then stops. No tag check, no GitHub Release, no tap change.

**Steps:**
- [ ] `ExportOptions.plist`: `method` `developer-id`, `teamID` `4HYL3L2W4Z`, `signingStyle` `manual`, `signingCertificate` `Developer ID Application`.
- [ ] **Script, `set -euo pipefail`, in this order:**
  1. **Preflight:**
     - `$version` matches `^[0-9]+\.[0-9]+\.[0-9]+$`;
     - `MARKETING_VERSION` in the project equals it;
     - except in `--dry-run`: the tree is clean, the branch is `main`, and tag `v$version` exists and points at `HEAD`;
     - `security find-identity -v -p codesigning` lists a Developer ID Application identity of team `4HYL3L2W4Z`;
     - `xcrun notarytool history --keychain-profile "$NOTARY_PROFILE"` succeeds;
     - except in `--dry-run`: `gh auth status` succeeds and `$TAP_DIR/Casks/keypad.rb` exists.
  2. **Build:** `xcodebuild archive -project Keypad.xcodeproj -scheme Keypad -configuration Release -archivePath build/release/Keypad.xcarchive CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=4HYL3L2W4Z`, then `xcodebuild -exportArchive … -exportOptionsPlist scripts/ExportOptions.plist -exportPath build/release/export`.
  3. **Check the app:** `codesign --verify --deep --strict` and `codesign -dvv` show `TeamIdentifier=4HYL3L2W4Z` and the runtime flag.
  4. **DMG:** stage `Keypad.app` and `ln -s /Applications`, then `hdiutil create -volname Keypad -srcfolder <stage> -format UDZO build/release/Keypad-$version.dmg`, then `codesign --sign "Developer ID Application" --timestamp` the DMG.
  5. **Notarize:** `xcrun notarytool submit <dmg> --keychain-profile "$NOTARY_PROFILE" --wait`; fail unless the status is `Accepted`. Then `xcrun stapler staple <dmg>` and `xcrun stapler validate <dmg>`, and `spctl --assess --type open --context context:primary-signature -v <dmg>`.
  6. **Checksum:** `shasum -a 256` gives the SHA-256; print it. `--dry-run` stops here.
  7. **Publish:** `gh release create "v$version" <dmg> --title "Keypad $version"`, with `--notes-file "$NOTES_FILE"` or `--generate-notes`.
  8. **Tap:** in `$TAP_DIR`, set `version` and `sha256` in `Casks/keypad.rb` and commit `keypad <version>`. Print the push command; the script never pushes.
- [ ] **Verify:**
  - `bash -n scripts/release.sh`.
  - `scripts/release.sh 1.2` fails on the version format.
  - With `MARKETING_VERSION` 0.1.0, `scripts/release.sh 0.2.0 --dry-run` fails on the version mismatch.

  Both failures must happen before any build. Real signing waits for Task 6.
- [ ] **Commit:** `build(release): add the signed, notarized release script`

### Task 5: Homebrew tap

**Files (new repository at `~/Repositories/berkan/homebrew-tap`):**
- Create: `Casks/keypad.rb` (RFC-0004 §4, with `sha256 :no_check` until Task 9 fills it in), `README.md` (one paragraph and the install command).

**Steps:**
- [ ] `git init`, with the repo-local identity set to the no-reply address. Write both files.
- [ ] **Verify:**
  - `brew style --cask Casks/keypad.rb` passes.
  - After `brew tap berkanaslan/tap <local path>` against the local clone, `brew audit --cask berkanaslan/tap/keypad` reports nothing but the missing download.
- [ ] **(controller + PM)** With the PM's OK: `gh repo create berkanaslan/homebrew-tap --public --source . --push`.
- [ ] **Commit (in the tap repo):** `keypad: add cask`

### Task 6: Credentials and a notarized dry run (controller + PM)

- [ ] **Guide the PM step by step** (RFC-0004, "What the PM does" 1–2):
  1. Create the Developer ID Application certificate.
  2. Create the App Store Connect API key.
  3. Run `xcrun notarytool store-credentials keypad-notary --key <path to .p8> --key-id <id> --issuer <issuer id>`.

  The PM types the values; the controller never sees or stores them.
- [ ] **Run** `scripts/release.sh 0.1.0 --dry-run`. Expect notarization `Accepted`, the stapler validating, `spctl` printing "accepted", and a SHA-256.
- [ ] **Fix any script defect** with a commit, `fix(release): …`.

### Task 7: Demo (controller + PM)

- [ ] **Write a shot list** (8–12 s):
  1. A spreadsheet with an empty column.
  2. ⌃⌥K.
  3. Tap "1234,5".
  4. Return.
  5. The number lands and the next cell is selected.
  6. Tap "42".
  7. Tab.
  8. Esc.
- [ ] **The PM records it** with the macOS screen recorder.
- [ ] **Convert to `docs/assets/demo.gif`** with `ffmpeg` if it is installed; otherwise as an MP4 GitHub can show, uploaded to the README by drag-and-drop in the GitHub editor (PM). Target width 960 px and under 5 MB.
- [ ] **Add the demo section** to the README.
- [ ] **Commit:** `docs: add the demo to the README`

### Task 8: Privacy rewrite and going public (controller + PM)

- [ ] **Install the tools:** `brew install git-filter-repo gitleaks`. They are not project dependencies.
- [ ] **Back up:** `git bundle create ../keypad-backup.bundle --all`.
- [ ] **Merge** this branch into `develop` with `--no-ff` first, so the rewrite covers everything.
- [ ] **Rewrite:** `git filter-repo --force --mailmap <file>`, where the file maps the old personal address to `Berkan Aslan <42192003+berkanaslan@users.noreply.github.com>` for authors and committers. Then restore the `origin` remote; filter-repo removes it.
- [ ] **Verify:**
  - `git log --all --format='%ae%n%ce' | sort -u` prints only the no-reply address and `noreply@github.com`.
  - The content scan from RFC-0004 §2 finds nothing new.
  - `gitleaks git --redact -v .` finds nothing.
  - Tests and lint pass on `develop`.
- [ ] **(controller + PM)** With the PM's OK: `git push --force origin main develop`. Delete the workflow runs from before the rewrite with `gh run list` and `gh run delete`.
- [ ] **(PM)** Turn on "Keep my email addresses private" and "Block command line pushes that expose my email" on GitHub.
- [ ] **(controller + PM)** With the PM's OK: `gh repo edit berkanaslan/keypad --visibility public --accept-visibility-change-consequences`. Set the description ("Turn your Mac's trackpad into a numeric keypad") and the topics `macos`, `trackpad`, `numpad`, `swift`, `homebrew`.

### Task 9: Release v0.1.0 (controller + PM)

- [ ] **Merge** `develop` into `main` with `--no-ff`; tag `v0.1.0`.
- [ ] **With the PM's OK:** `git push origin main v0.1.0`.
- [ ] **Run** `scripts/release.sh 0.1.0`. It creates the GitHub Release and the tap commit with the real SHA-256.
- [ ] **With the PM's OK:** push the tap.
- [ ] **(PM)** On a clean user account:
  1. `brew install --cask berkanaslan/tap/keypad`: Keypad opens without a Gatekeeper warning.
  2. Grant Accessibility; a commit types into TextEdit.
  3. `brew uninstall --zap --cask keypad`: the app and `~/Library/Containers/io.berkan.keypad` are gone.

### Task 10: Close RFC-0004

- [ ] **Record the release** in a "Release results" section of RFC-0004: the notarization ID, the install check, and what was deferred (keypad.berkan.io and the layered icon).
- [ ] **Mark RFC-0004 Implemented** in the RFC and the index.
- [ ] **Final review** of the branch, merge, and ask the PM before pushing.
