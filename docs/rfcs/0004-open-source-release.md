# RFC-0004: Open Source Release

| Field      | Value                                        |
|------------|----------------------------------------------|
| Status     | Accepted                                     |
| Authors    | Claude (development lead), Berkan Aslan (PM) |
| Created    | 2026-10-30                                   |
| Depends on | RFC-0000, RFC-0003                           |

## Summary

Keypad leaves the Mac App Store plan and ships as free, MIT-licensed open source.

- **Distribution:** a Developer ID-signed, notarized app in GitHub Releases, installed with Homebrew from our own tap.
- **Privacy:** before the repository goes public, every personal detail leaves the files and the git history.
- **Identity:** the README becomes the product page, and the Aluminum icon ships.

This RFC amends RFC-0000 (G8, §4, §6, §11–§14) and AGENTS.md, and absorbs the planned RFC-0006 (app identity) and RFC-0007 (release).

## Motivation

- **App Review:** throughout 2026, App Review rejected Mac apps that use the Accessibility-labelled permission to type into other apps (Guideline 2.4.5).
  - One developer reports an Apple call that said "no exceptions".
  - An app that used the planned fallback, a virtual HID keyboard, was rejected too.
  - Typing the number into another app is Keypad's whole purpose.
- **The PM's decision (2026-10-30):** publish Keypad as free, open-source software instead.
- **Trust:** an app that asks for Accessibility access and posts keystrokes earns trust when anyone can read what it does with them.

## Decisions by the PM (2026-10-30)

1. Free forever, MIT licence, no revenue path of any kind.
2. No personal information in the files or the history. Follow what open-source projects do.
3. Distribution through Homebrew, researched and specified here.
4. The README is the product page, to the standard of well-known Homebrew-installed apps.
5. If needed, a page at keypad.berkan.io, built inside the `berkanio` repository.
6. The Aluminum icon (direction A on the "Keypad App Icon" canvas) ships as the app icon.

## Design

### Amendments to RFC-0000 and AGENTS.md

Applied when this RFC is accepted.

| Where | Today | After |
|---|---|---|
| RFC-0000 G8 | Mac App Store compliant | Free, MIT-licensed open source, distributed outside the Mac App Store: Developer ID-signed, notarized, installed with Homebrew. Still sandboxed, public APIs only, no network. |
| RFC-0000 §4 | No in-app purchases, subscriptions or trials | No revenue path of any kind: no purchases, licence keys, donation links or sponsorship |
| RFC-0000 §6 | Distribution: Mac App Store; Business: one-time paid | Distribution: GitHub Releases and a Homebrew tap; Business: free, MIT |
| RFC-0000 §11 | App Review risk (Guideline 2.4.5) | Replaced by this RFC's risks |
| RFC-0000 §12 | 0006 App identity, 0007 Release | Both merged into RFC-0004; 1.0 after RFC-0005 |
| RFC-0000 §13 | Mac App Store; one-time paid | The six PM decisions above |
| AGENTS.md §1 | "ships on the Mac App Store as a one-time paid…" | "is free, MIT-licensed open source, installed with Homebrew…" |
| AGENTS.md §4 | The owner's personal git identity | The owner's GitHub no-reply address |
| AGENTS.md §7 | Apple Development signing | Apple Development for local builds; Developer ID Application for releases, team `4HYL3L2W4Z` |
| AGENTS.md §10 | — | The release command |

The App Sandbox stays. It is least privilege, costs nothing, and keeps a future App Store attempt possible.

### 1. Licence

- An MIT `LICENSE` at the root: `Copyright (c) 2026 Berkan Aslan`. Open question 1 decides the holder.
- `Info.plist` today says "All rights reserved", which contradicts MIT. It becomes `© 2026 Berkan Aslan. MIT License.`

### 2. Privacy scrub

**Scan of 2026-10-30 (85 commits, every branch, full patch history):**

| Found | Verdict |
|---|---|
| Email addresses, local paths, company names, certificate fingerprints in files or diffs | None |
| Team ID `4HYL3L2W4Z` | Allowed: it is in every signed build anyway |
| The owner's name, the bundle identifier `io.berkan.keypad` | Allowed (AGENTS.md §4) |
| `Co-Authored-By: Claude …` trailers | No personal data; kept |
| **Author and committer email of every commit: the owner's personal address** | **Must go** |

**What open-source projects do, and what we do:**

- **Keep design documents public.** Swift Evolution, Rust's RFCs and architecture decision records are all public, because the reasoning is as valuable as the code. Our RFCs, plans and glossary stay.
- **AGENTS.md stays.** It is now an open standard that tens of thousands of repositories ship. Its owner-specific parts (the local signing override, "the owner's personal identity") become contributor rules.
- **Fix commit emails before the first publication**, while nobody has cloned the repository.
  - Rewrite every commit, on all branches and tags, with `git filter-repo --mailmap`.
  - The new author and committer email is GitHub's no-reply address for the account, `42192003+berkanaslan@users.noreply.github.com`. The name stays.
  - Make a backup bundle first; force-push `main` and `develop` once, with the PM's OK at that moment.
- **Keep it that way.** The repo-local git config uses the no-reply address. On GitHub, the PM turns on "Keep my email addresses private" and "Block command line pushes that expose my email".
- **Scan again after the rewrite**, then flip the repository to public:
  - the same searches as above, on the rewritten history;
  - a secret scan with `gitleaks`, run locally and not added to the project.
- **Workflow runs** recorded before the rewrite are deleted.

### 3. Signing and notarization

- **Release builds:**
  - signed with a Developer ID Application certificate of team `4HYL3L2W4Z`;
  - Hardened Runtime on, with a secure timestamp;
  - still sandboxed.

  These are Apple's notarization requirements. Accessibility (PostEvent) needs no extra entitlement under the Hardened Runtime.
- **One command, `scripts/release.sh <version>`, run on the PM's Mac:**
  1. Check that the tag, the project's version and a clean `main` agree.
  2. Archive the Release build and export it with the Developer ID method.
  3. Build `Keypad-<version>.dmg` (the app and an Applications link) and sign it.
  4. Submit with `xcrun notarytool submit … --keychain-profile keypad-notary --wait`, staple with `xcrun stapler staple`, and verify with `spctl --assess`.
  5. Create the GitHub Release with `gh release create v<version>`, upload the DMG, and update the tap's cask (§4) with the new version and SHA-256, committed for the PM to push.
- **Credentials never enter the repository or CI.** The certificate lives in the PM's keychain. The notarization key is stored once with `xcrun notarytool store-credentials keypad-notary`.
- **CI** keeps building and testing unsigned. Signing in CI can come later.

### 4. Homebrew

**How it works, in plain words:**
- A **cask** is a small Ruby file that says where to download an app and how to install it.
- A **tap** is a GitHub repository of casks.
- `brew install --cask berkanaslan/tap/keypad` reads our cask, downloads the DMG from GitHub Releases, checks its SHA-256, lets Gatekeeper check the notarized app, and moves `Keypad.app` to `/Applications`.
- When the cask's version changes, `brew upgrade` installs the new release. The app itself never goes online.
- Since Homebrew 6, third-party taps must be trusted. Installing by the full name trusts only that cask.

**Our tap:** a new public repository, `berkanaslan/homebrew-tap`. The `homebrew-` prefix gives the short `brew tap` form. It holds `Casks/keypad.rb`, written to the rules the official repository uses (stanza order, `livecheck`, `zap`):

```ruby
cask "keypad" do
  version "0.1.0"
  sha256 "<sha-256 of the DMG>"

  url "https://github.com/berkanaslan/keypad/releases/download/v#{version}/Keypad-#{version}.dmg"
  name "Keypad"
  desc "Turns the trackpad into a numeric keypad"
  homepage "https://github.com/berkanaslan/keypad"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "Keypad.app"

  zap trash: [
    "~/Library/Application Scripts/io.berkan.keypad",
    "~/Library/Containers/io.berkan.keypad",
  ]
end
```

**The official `homebrew/cask` repository comes later.**
- Not eligible yet: an owner's own submission needs 225 stars, 90 forks or 90 watchers, and a repository at least 30 days old.
- It also needs an app that passes Gatekeeper, and Homebrew removes casks that fail it.
- Our cask already follows the official rules, so it can move there unchanged once Keypad qualifies.
- No official cask is named `keypad` today. `keypad-layout` exists, so the README names ours in full.

### 5. Versions and releases

- **SemVer.** A release merges `develop` into `main` with `--no-ff` and tags `vX.Y.Z` (AGENTS.md §4). GitHub Release notes are in English.
- **First public release `v0.1.0`** right after this RFC. **`v1.0.0`** after RFC-0005 (onboarding and permission recovery). Open question 2.

### 6. README as the product page

The model is the READMEs of well-known Homebrew-installed Mac utilities: an icon and a one-line pitch, a demo, install first, then the details. Sections:

1. **Header:** centred icon (256 px), name, one-line pitch, and badges for the latest release, macOS 26+, MIT and Homebrew.
2. **Demo:** a short GIF of a real session. The PM records it from a shot list I write; it needs a real trackpad.
3. **Install:** `brew install --cask berkanaslan/tap/keypad`, or the DMG from Releases. Then first launch: why Keypad needs Accessibility, and how to grant it later if the prompt was dismissed.
4. **Use:** the shortcut, tapping, the commit-key table, Esc and "stay open", and Settings.
5. **Features.**
6. **Privacy:** no network, no analytics, nothing leaves the Mac, and the source to check it.
7. **FAQ:**
   - Why Accessibility?
   - Why not in password fields?
   - What happens with Spotlight and Mission Control?
   - Why not on the App Store?
8. **Build from source, contributing** (AGENTS.md, RFCs), **licence.**

Assets live in `docs/assets/`. English only for now (open question 4).

### 7. keypad.berkan.io (optional)

- **Where:** a `/keypad` page in the `berkanio` repository (Next.js on Vercel).
  - The Vercel project adds the domain `keypad.berkan.io`, and a host-based rewrite serves `/keypad` there.
  - DNS: a CNAME for `keypad` pointing to the value Vercel shows.
- **Content:** the README's sections and assets, with a download button for the latest release.
- **Timing:** after `v0.1.0`; the README comes first. It is a change in another repository, made there.
- The site loads Vercel Analytics today. Whether the Keypad page should is open question 3.

### 8. App icon

- **Asset:** the Aluminum artboard's 1024 px rendering, exported to the ten macOS sizes in `Keypad/Resources/Assets.xcassets/AppIcon.appiconset`.
  - PNG is a format Apple's guidelines allow.
  - Canvas defaults: accent `#0A84FF`, skin `#F2B18F`, separator `,`.
- The same image, at 256 px, heads the README and the page.
- A layered Icon Composer version (Liquid Glass, dark and tinted appearances) is a later follow-up.
- **Known risk, accepted by the PM:**
  - Apple's guidelines say "Don't use replicas of Apple hardware products" because Apple products are copyrighted. Direction A draws a MacBook top case.
  - Outside the App Store no review enforces this, but the copyright point stands.
  - Fallback: drop the keyboard row and the MacBook proportions (direction C's layout in aluminium), about half a day.

### What the PM does

Each of these needs the PM's own accounts or approval:

1. Create a **Developer ID Application** certificate (Xcode › Settings › Accounts › Manage Certificates; only the Account Holder can).
2. Create an **App Store Connect API key** (Users and Access › Integrations › Team Keys, Developer role), then run the `notarytool store-credentials` command the release script prints.
3. On GitHub, turn on **"Keep my email addresses private"** and **"Block command line pushes that expose my email"**.
4. Approve the one **history rewrite and force-push**.
5. Make **`keypad` public**, and approve creating **`homebrew-tap`**.
6. Record the **demo GIF**.
7. Optional: the **DNS record** for keypad.berkan.io.

### Verification

- **Release script:** notarization "Accepted"; `stapler validate`; `spctl --assess --type open --context context:primary-signature` accepts the DMG.
- **Tap:** `brew style` and `brew audit --cask` pass for `berkanaslan/tap/keypad`.
- **On a clean user account:**
  - `brew install --cask berkanaslan/tap/keypad` installs and opens Keypad without a Gatekeeper warning;
  - `brew uninstall --zap` removes the app and its container.
- **Privacy:** the scan, re-run on the rewritten history, finds nothing before the repository goes public.

## Alternatives considered

| Alternative | Decision |
|---|---|
| Keep aiming for the Mac App Store | Rejected: 2026 rejections of exactly this behaviour, no exceptions. |
| Paid download outside the App Store (licence keys) | Rejected: the PM wants it free; licence checks would also need the network. |
| Publish one squashed commit instead of the history | Rejected: it loses the RFC-by-RFC record, and the content is clean; only emails change. |
| Sparkle auto-updates | Rejected: needs the network and an appcast; `brew upgrade` covers updates. |
| Sign and notarize in GitHub Actions | Later: keeping secrets on the PM's Mac is simpler and safer for now. |
| Submit to the official `homebrew/cask` now | Not eligible yet (age, notability); the cask is ready for it. |
| Product page on GitHub Pages in this repository | The PM prefers `berkanio`; the README comes first anyway. |
| Drop the App Sandbox now that the App Store is gone | Rejected: least privilege and no cost. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A history rewrite goes wrong | Low | Backup bundle first; re-run the scan and the tests on the rewritten history; push only with the PM's OK. |
| Notarization or Gatekeeper fails on a release | Medium | The script stops before uploading unless notarization, stapling and `spctl` all pass. |
| Users balk at Homebrew's tap-trust step | Medium | The README uses the fully qualified install command, which trusts only our cask. |
| A secret lands in the public repository | Low | No secrets are needed in the repository or CI; `gitleaks` before going public. |
| Apple objects to the hardware look of the icon | Low | Switch to the variant without the keyboard row. |
| `brew install` shows the old version after a release | Low | The release script updates the cask in the same run; `livecheck` makes drift visible. |

## Rollout

1. Amendments to RFC-0000 and AGENTS.md, `LICENSE`, the `Info.plist` copyright.
2. The app icon.
3. README and `docs/assets/`. The PM records the demo.
4. `scripts/release.sh`. The PM creates the certificate and the API key, then a dry run that notarizes without publishing.
5. The `homebrew-tap` repository and `Casks/keypad.rb`.
6. The privacy rewrite and scan; the PM approves the force-push and makes `keypad` public.
7. Release `v0.1.0`; verify the Homebrew install on a clean account.
8. Optional: keypad.berkan.io in `berkanio`.

Done when the scan finds nothing, `v0.1.0` installs and opens through Homebrew on a clean account, and the README reads as a product page.

## Open questions

Accepted by the PM on 2026-10-30 with the drafted defaults: the holder is "Berkan Aslan", `v0.1.0` comes first and `v1.0.0` after RFC-0005, and the development-lead calls stand. Question 3 is settled when the page is built.

1. **Copyright holder in `LICENSE`:** "Berkan Aslan" (your name, already visible in the GitHub username) or "Keypad contributors"?
2. **First public version:** `v0.1.0` now and `v1.0.0` after RFC-0005, or wait for onboarding and start at 1.0?
3. **keypad.berkan.io:** keep Vercel Analytics off the Keypad page?
4. **Development-lead calls you may overrule:**
   - the README in English only for now;
   - signing and notarization by a local script rather than CI;
   - the icon's separator `,`;
   - keeping the App Sandbox.
