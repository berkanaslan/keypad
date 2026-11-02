# AGENTS.md

Rules for every agent and contributor working in this repository.

## 1. Product

Keypad for Mac turns the Mac trackpad into a temporary numeric keypad: in any app the user presses a shortcut, taps numbers on the trackpad, and the number is typed into the field they were working in. It is free, MIT-licensed open source, installed with Homebrew from the project's own tap, and fully offline and fully native. It is not on the Mac App Store (RFC-0004).

The big picture lives in [RFC-0000](docs/rfcs/0000-vision-and-architecture.md); domain terms in the [glossary](docs/glossary.md).

## 2. Language

- Write all code, comments, docs, RFCs and commit messages in English.
- The PM may write in Turkish or English in chat; answer in the language they use.

## 3. Process

- Work one RFC at a time: write it in `docs/rfcs/`, get it accepted, implement it, then write the next.
- Only the PM accepts an RFC.
- Put implementation plans in `docs/plans/YYYY-MM-DD-<topic>.md`.
- When behaviour or terms change, update the RFC and the glossary in the same branch.

## 4. Git

- Create a branch from `develop` before the first commit: `feature/…`, `bugfix/…`, `chore/…`, `refactor/…` or `docs/…`.
- Before merging, squash the branch into one Conventional Commit whose body lists the work, then merge it into `develop` with `--no-ff`, so every merge brings exactly one commit.
- `main` only receives `develop` at release time, merged with `--no-ff` and tagged `vX.Y.Z`.
- Commit with a GitHub no-reply address (`<id>+<username>@users.noreply.github.com`), set in the repository's local git config; the maintainer's is `42192003+berkanaslan@users.noreply.github.com`. Never commit with any other identity configured on the machine; in a new clone, set `git config user.name` and `git config user.email` before the first commit.
- Never commit personal or affiliation data: email addresses, employers or clients, other teams' IDs, certificate fingerprints or local machine paths. Allowed: the project owner's name (copyright, RFC authorship, git identity), GitHub no-reply addresses, the project's team ID and the bundle identifier. Naming third-party apps as test targets (e.g. in a QA matrix) is fine.
- Write Conventional Commits, e.g. `feat(session): reclaim focus after commit`.
- Never push without the PM's explicit OK.

## 5. Architecture

| Module | Responsibility | Depends on |
|---|---|---|
| `KeypadCore` | Pure domain: layouts, hit-testing, active area, tap recognition, buffer, session state machine, settings model, protocols for every system service. | Foundation only |
| `KeypadSystem` | macOS adapters implementing the Core protocols (hotkey, capture panel, key events, focus hand-off, feedback, permissions, login item). | `KeypadCore` |
| `KeypadUI` | SwiftUI views: HUD, Settings, onboarding. | `KeypadCore` |
| `Keypad` app target | Composition root: wiring, app and Dock lifecycle, resources. | all of the above |

- Point dependencies towards `KeypadCore`; never the other way.
- Never import AppKit, Carbon or SwiftUI in `KeypadCore`.
- Put every system service behind a Core protocol so Core stays testable without a trackpad.
- Keep the app target thin; logic belongs in the package.

## 6. Platform rules

- Use public APIs only. No private frameworks, no undocumented selectors.
- No network access and no network entitlement.
- Stay inside the App Sandbox; the only entitlement is `com.apple.security.app-sandbox`.
- Target macOS 26 and later.
- Use SwiftUI first; use AppKit only where SwiftUI has no equivalent (panels, touches, events).
- Use system controls, materials and metrics only. No custom-drawn look.
- Respect the verified technical foundation in RFC-0000 §7 (F1–F11) before changing input, focus or key delivery.

## 7. Signing

- Sign only with the team pinned in the project, `4HYL3L2W4Z`.
- Never use any other team, identity, certificate or account.
- Local signed builds use Apple Development with the override in §10. Never commit the override.
- Releases use a Developer ID Application certificate and are built only by `scripts/release.sh` on the maintainer's Mac, which notarizes them. Signing credentials never enter the repository or CI.
- Contributors without access to the team build unsigned (§10).
- After every signed build, verify the team (§10). Anything other than `TeamIdentifier=4HYL3L2W4Z` is a stop.

## 8. Localization

- Put every user-facing string in a String Catalog (`.xcstrings`); never hard-code one.
- Add the English and Turkish values in the same commit that introduces the string.

## 9. Code style

- Write self-explanatory code. Comment only a non-obvious reason, never what the code does.
- Follow DRY, SOLID and KISS. Don't build what no RFC asks for.
- Treat warnings as errors (already enforced in the package and the app target).
- `.swift-format` is the source of truth for formatting.
- Add no third-party dependency without an RFC.

## 10. Commands

Run from the repository root.

Format:

```bash
swift format format --in-place --recursive Packages Keypad
```

Lint:

```bash
swift format lint --recursive --strict Packages Keypad
```

Test:

```bash
swift test --package-path Packages/KeypadKit
```

Signed build (local, with the identity override from §7):

```bash
xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug \
  -derivedDataPath build/DerivedData CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=4HYL3L2W4Z build
```

Verify the signing team (must print `TeamIdentifier=4HYL3L2W4Z`):

```bash
codesign -dvv build/DerivedData/Build/Products/Debug/Keypad.app 2>&1 | grep TeamIdentifier
```

Unsigned build (what CI runs):

```bash
xcodebuild -project Keypad.xcodeproj -scheme Keypad -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Release (maintainer only, on `main` at tag `vX.Y.Z`, with `main` and the tag pushed; `--dry-run` signs and notarizes HEAD without publishing; `--tap-only` repeats just the cask update):

```bash
scripts/release.sh X.Y.Z
```

## 11. Definition of done

- Lint prints nothing.
- All tests pass, and new behaviour has a test that failed first.
- Every new user-facing string has English and Turkish values.
- The RFC and the glossary reflect any change in behaviour or terms.
