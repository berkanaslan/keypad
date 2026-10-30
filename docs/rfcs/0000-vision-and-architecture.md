# RFC-0000: Vision, Principles and Architecture

| Field   | Value                                        |
|---------|----------------------------------------------|
| Status  | Accepted                                     |
| Authors | Claude (development lead), Berkan Aslan (PM) |
| Created | 2026-10-26                                   |

## 1. Summary

Keypad for Mac turns the Mac trackpad into a temporary numeric keypad. In any app, the user presses a shortcut, taps numbers on the trackpad, and the number is typed into the field they were working in. It ships on the Mac App Store as a one-time paid, fully offline, fully native macOS app.

This RFC is the umbrella design: intent, scope, constraints, the technical foundation verified by a spike, the v1 user experience, the architecture, the engineering process and the roadmap of follow-up RFCs. Every roadmap item gets its own RFC before implementation.

## 2. Intent

Most Mac laptops and the compact Magic Keyboard have no numeric keypad. People who enter numbers — invoices, spreadsheets, forms, prices — either use the number row or buy an external numpad. The trackpad sits right under their hands and is idle while they type. Keypad makes it a numpad on demand, with no extra hardware, and gets out of the way the moment the user is done.

Success: someone who has never seen the app installs it, grants one permission, and enters a column of numbers into a spreadsheet faster than with the number row — and the app looks and behaves as if Apple shipped it.

## 3. Goals (v1)

- **G1** A keypad session starts from any app with a configurable shortcut.
- **G2** Touches map reliably to keys on the part of the trackpad the user configures.
- **G3** Numbers reach the previously focused field in any app (native, Chromium, Electron).
- **G4** A keyboard-driven commit keeps the session open for continuous entry (spreadsheets, forms).
- **G5** Haptic and sound feedback, both on by default, each switchable.
- **G6** Native Liquid Glass UI in light and dark mode, in English and Turkish.
- **G7** A Dock app with launch at login (with consent) and a Dock menu to disable and enable it.
- **G8** Mac App Store compliant: sandboxed, public APIs only, no network.

## 4. Non-goals (v1)

- Volume and brightness gestures. They get a later RFC; the layout model is ready for slider cells.
- Live typing into the target app while the session is open (verified unreliable in Chrome, see F5).
- A scientific calculator. The later calculator RFC is scoped to arithmetic: + − × ÷, precedence, optionally parentheses and percent, computed with `Decimal`.
- App-specific behaviour built by us. Users may assign layouts to apps in a later RFC.
- In-app purchases, subscriptions or trials.
- A menu bar extra. The app lives in the Dock.
- Analytics, telemetry, accounts or any network access.
- Languages beyond English and Turkish.

## 5. Anti-goals

Keypad fails, even if it technically works, if it:

- looks custom-drawn instead of like something Apple made;
- uses private APIs or anything else that puts App Store eligibility at risk;
- interferes with normal trackpad use when no session is open;
- leaves focus in the wrong app, loses a typed number or types into the wrong field;
- hides what the user typed (the display never truncates);
- collects or transmits user data.

## 6. Constraints

| Area | Constraint |
|---|---|
| Distribution | Mac App Store; App Sandbox; public APIs only |
| Platform | macOS 26 Tahoe minimum (Liquid Glass); built with Xcode 27 in the Swift 6 language mode |
| UI | SwiftUI first, AppKit where SwiftUI has no equivalent (panels, touches); system controls and materials only |
| Network | None; no network entitlement |
| Permissions | Accessibility, for posting key events (`kTCCServicePostEvent`) — nothing else |
| Localization | String Catalogs; English (development language) and Turkish |
| Signing | Team `4HYL3L2W4Z` (the project owner's account) only. No other team may be used. |
| Language | All code, docs, RFCs and commits in English |
| Code style | Self-explanatory code, minimal comments, DRY, SOLID, KISS |
| Business | One-time paid download, no in-app purchases |

## 7. Verified technical foundation

A throwaway sandboxed spike (2026-10-26, macOS 26, a Mac with a Force Touch trackpad, signed with the team above) established how the app can work within App Store rules. These are observed facts, not proposals.

| # | Finding | Consequence |
|---|---|---|
| F1 | There is no public API for system-wide raw trackpad touches. MultitouchSupport is private; the built-in trackpad's HID reports are reserved for Apple's driver. | Touches can only be read through AppKit (`NSTouch`). |
| F2 | `NSTouch` (`allowedTouchTypes = [.indirect]`) reaches a view only when our app is active **and** its window is key. A non-activating, non-key panel received 0 touches. | A session must activate the app and make a capture panel key. |
| F3 | `NSApp.activate()` triggered from a CGEventTap callback is often refused (cooperative activation, macOS 14+). Triggered from a Carbon `RegisterEventHotKey` handler it succeeded 13 of 13 times. | The trigger is a registered hotkey, which needs no Input Monitoring permission. Modifier-only triggers (such as holding fn) are not supported. |
| F4 | Holding fn/🌐 opens the emoji picker on release. | fn cannot be a trigger. |
| F5 | Posting key events into an inactive app (`postToPid` or the HID tap) works in Claude (Electron) but not in Chrome. | No live typing: digits are buffered and typed after focus is handed back. |
| F6 | Hand-back sequence: `NSApp.yieldActivation(to:)`, `target.activate(from: .current)`, wait for `NSWorkspace.didActivateApplicationNotification` for the target, wait about 60 ms, then post with `CGEvent.post(tap: .cghidEventTap)`. Posting before the notification lost keys in Claude. | Commit is driven by the notification, not by a timer. |
| F7 | After a commit, `NSApp.activate()` reclaimed focus 12 of 12 times; a full commit cycle takes about 300 ms. | Sticky sessions are possible. |
| F8 | The commit key keeps its meaning in the target app: Return sends or searches, ⇧Return inserts a newline. | The keyboard decides what a commit means; Keypad doesn't. |
| F9 | Activating the app brings its other windows forward. Ordering them out during the session fixes this. | The Settings window hides while a session is open. |
| F10 | `NSHapticFeedbackManager` plays only while a finger is on the surface. Firing on tap completion (finger lifted) does nothing. | Haptic on touch-down, sound on tap. |
| F11 | `CGEvent` posting needs the Accessibility permission for posting events; Apple DTS says it is sandbox-compatible. macOS shows the system prompt only once per app; after that the user has to be guided to System Settings. | Onboarding must handle the "prompt already used" path. |

Open risk: App Review has rejected apps that post events under Guideline 2.4.5 ("Accessibility features for non-accessibility purposes"). See §11.

## 8. User experience (v1)

### 8.1 Lifecycle and Dock

- A regular Dock app with no menu bar extra. Clicking the Dock icon opens Settings.
- Launch at login uses `SMAppService.mainApp`. App Review Guideline 2.4.5(iii) requires consent before code runs at login, so onboarding presents the option pre-selected and the user confirms it. Settings can turn it off.
- The Dock menu offers "Disable Keypad" or "Enable Keypad", and "Settings…". While disabled, the hotkey is unregistered and the Dock icon shows the disabled state.

### 8.2 Keypad session

1. The user presses the shortcut (default ⌃⌥K, configurable) in any app.
2. Keypad remembers the frontmost app, activates, and shows a full-screen capture panel on the display under the pointer. A Liquid Glass HUD in the centre shows the target app (icon and name), the number display, the key grid and a one-line hint ("Return, Tab or arrows to type · Esc to close").
3. The pointer freezes. Clicks, scrolls and gestures are swallowed; nothing reaches the app underneath.
4. Touch-down on a cell plays the haptic. A completed tap plays the sound, applies the key's action and briefly highlights the key.
5. The number builds up in the HUD display. Backspace (the ⌫ cell or the Delete key) removes the last character. Digit, decimal and Delete keys on the physical keyboard also edit the number; other keys are ignored unless they commit (§8.3).
6. The display never truncates: it widens first, then scales the text down, then wraps.

### 8.3 Commit

| Key on the keyboard | Effect |
|---|---|
| Return, ⇧Return, keypad Enter | Type the number, then send that key |
| Tab, ⇧Tab | Type the number, then send that key (next or previous cell) |
| ← ↑ → ↓ | Type the number, then send that arrow |
| Esc | Close the session; nothing is typed |
| The shortcut again | Type the pending number (no extra key) and close |

- After a Return, Tab or arrow commit the session stays open ("sticky") for the next number. Sticky is a setting, on by default.
- A commit with an empty buffer still sends its key, so the user can move between cells without leaving the session.
- The decimal cell posts the keypad decimal key, so the active keyboard layout produces "," or ".". The HUD shows the current locale's separator.

### 8.4 Layouts

- A layout is data: a grid of rows and columns whose cells map to actions — digit, decimal, backspace in v1; operators, commit keys and sliders later.
- v1 ships one built-in layout, "Numpad": 3 columns × 4 rows, `7 8 9 / 4 5 6 / 1 2 3 / 0 , ⌫`. This interprets the PM's "3×3 standard" as three columns of digits plus a bottom row.
- Custom layouts with drag-and-drop editing come in a later RFC. The model and persistence support them from day one.

### 8.5 Active trackpad area

The user chooses which part of the physical trackpad acts as the keypad (size and position, stored as a normalized rectangle). Touches outside it are ignored. Settings shows a trackpad-shaped preview with handles. The default is the whole surface.

### 8.6 Onboarding and permission

On first launch an onboarding window walks through four steps:

1. What Keypad does: one sentence and an illustration of the shortcut.
2. The Accessibility permission: why it's needed (Keypad types numbers for you), then `CGRequestPostEventAccess()`, polling `CGPreflightPostEventAccess()`. If the system prompt doesn't appear because it was already used, an "Open System Settings" button deep-links to Privacy & Security → Accessibility, with instructions for adding the app.
3. Launch at login, as a pre-selected toggle.
4. Try it: press the shortcut and type a number into a practice field.

Settings shows the permission state and offers the same recovery path if the permission is revoked later.

### 8.7 Settings

A Settings window with Apple-standard tabs (RFC-0003 has the details):

- **General**: Enable Keypad, Launch at login, shortcut recorder.
- **Keypad**: active area, stay open after commit. The layout picker comes with the layout editor (RFC-0008).
- **Feedback**: haptics on or off with a pattern, key sound on or off with a choice of four sounds.
- The version and copyright are in the standard About panel.

### 8.8 Platform behaviour

Light and dark mode, Reduce Transparency and Reduce Motion, VoiceOver labels for Keypad's own UI, multiple displays (the session opens on the display under the pointer) and full-screen spaces (the panel joins all spaces).

## 9. Architecture

### 9.1 Repository layout

Proposed here, finalized in RFC-0001.

```
keypad/
├── AGENTS.md               rules for AI agents (CLAUDE.md points here)
├── README.md
├── docs/
│   ├── rfcs/               NNNN-kebab-title.md
│   └── glossary.md
├── Keypad.xcodeproj        app target only, synchronized folders
├── Keypad/                 composition root, Info.plist, entitlements, assets, Localizable.xcstrings
├── Packages/KeypadKit/     local Swift package with all logic and tests
└── .github/workflows/      CI
```

### 9.2 Modules

Three targets in `KeypadKit` plus the app target as the composition root. Dependencies point inward, towards `KeypadCore`.

| Module | Responsibility | Depends on |
|---|---|---|
| `KeypadCore` | Pure domain: layout model, hit-testing (normalized point → cell), active area, tap recognition, entry buffer, session state machine, settings model, and the protocols for every system service (`TouchSource`, `HotkeyRegistrar`, `KeystrokeSender`, `FocusHandoff`, `FeedbackPlayer`, `PermissionChecker`, `LoginItemController`). No AppKit. | Foundation |
| `KeypadSystem` | macOS adapters implementing the Core protocols: Carbon hotkey, capture panel with `NSTouch`, CGEvent sender, focus hand-off, haptics and sounds, permission checks, `SMAppService`. | KeypadCore, AppKit, Carbon |
| `KeypadUI` | SwiftUI: HUD, Settings, onboarding, active-area editor. | KeypadCore |
| App target | Dependency wiring, app and Dock lifecycle, resources. | all of the above |

Core is unit-testable without a trackpad. Adapters stay thin and replaceable — for example a future CoreHID `HIDVirtualDevice` sender — without touching the domain. That buys the open/closed and dependency-inversion parts of SOLID without the module sprawl that would break KISS.

### 9.3 Session state machine

```
idle ──shortcut──▶ capturing ──Return / Tab / arrow──▶ committing ──typed, sticky──▶ capturing
 ▲                  │    ▲                                  │
 │                  │    └── tap / backspace (buffer)       └──typed, not sticky──▶ idle
 └── Esc / shortcut ┘
```

Committing means: hand focus back (F6), type, then reclaim focus (F7) if sticky. The state machine lives in Core and drives the adapters through protocols.

### 9.4 Persistence

Settings in `UserDefaults` behind a typed settings store. Layouts as versioned `Codable` JSON in Application Support (inside the sandbox container). No iCloud sync in v1.

### 9.5 Concurrency

Swift 6 strict concurrency. UI and system adapters are `@MainActor`; Core types are `Sendable` value types where possible.

### 9.6 Testing

- Swift Testing for Core: hit-testing, tap recognition, buffer, and the state machine with fake adapters.
- Adapters are covered by a manual QA checklist on a real trackpad: an app matrix (TextEdit, Notes, Safari, Chrome, an Electron app such as Claude, Numbers, Google Sheets, Excel if available), multiple displays, full-screen spaces, dark mode and the Turkish locale.

## 10. Engineering process

### 10.1 RFCs

- Files live in `docs/rfcs/NNNN-kebab-title.md`. Status moves `Draft → Accepted → Implemented`, or to `Superseded`.
- Cadence: write and accept one RFC, implement it, then write the next — instead of writing every RFC upfront — so each RFC benefits from what the previous implementation taught us. RFC-0000 keeps the big picture coherent.
- The PM accepts RFCs.

### 10.2 Git

- `main` holds released code only. `develop` is the integration branch, created from `main`.
- Every change gets its own branch from `develop` before the first commit: `feature/…`, `bugfix/…`, `chore/…`, `refactor/…`, `docs/…`.
- Branches merge into `develop` with `--no-ff`. A release merges `develop` into `main` with `--no-ff` and is tagged `vX.Y.Z`.
- Commit messages follow Conventional Commits, for example `feat(session): reclaim focus after commit`.

### 10.3 Documentation

- `AGENTS.md` holds the rules for agents: process, style, signing. `CLAUDE.md` refers to it.
- `docs/glossary.md` defines domain terms: session, capture panel, commit, sticky, active area, layout, cell.
- Inline documentation only where the reason behind the code isn't obvious.

## 11. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| App Review rejects under Guideline 2.4.5 (event posting) | Medium | Before 1.0, an App Review consultation (Meet with Apple) with a TestFlight build; precise review notes and a demo video. The `KeystrokeSender` protocol keeps a CoreHID `HIDVirtualDevice` sender possible as a fallback (it needs an entitlement request). |
| A future macOS changes activation or touch delivery | Low to medium | Keep the spike findings as a regression checklist; test every macOS beta. |
| Focus timing differs between apps | Medium | Notification-driven hand-off (F6), the settle delay as a tunable constant, the QA app matrix. |
| Secure Event Input (password fields) blocks the hotkey | Unknown | Verify in RFC-0002 and document the behaviour. |
| Trackpads without Force Touch | Low | Haptics silently do nothing. |
| Permission friction lowers conversion | Medium | Clear onboarding and the System Settings recovery path (F11). |

## 12. Roadmap

| RFC | Title | Scope |
|---|---|---|
| 0001 | Repository foundations | Repo layout, Xcode project and package, signing, AGENTS.md, glossary, CI (build and test) |
| 0002 | Keypad session | Hotkey, capture panel, touches → taps → cells, buffer, HUD, commit, sticky, focus hand-off |
| 0003 | Feedback and settings | Haptic patterns and key sounds; Settings window, persistence, Dock menu and disabled state, launch at login, shortcut recorder, active-area editor |
| 0004 | Open source release | MIT licence, privacy scrub, Developer ID signing and notarization, GitHub Releases, Homebrew tap, README as product page, app icon (absorbs 0006 and 0007) |
| 0005 | Onboarding and permissions | First-run flow, permission states, recovery |
| 0006 | — | Merged into RFC-0004 |
| 0007 | — | Merged into RFC-0004 |
| — | **1.0** | Proposed release cut after RFC-0005; the PM decides |
| 0008 | Layout editor | Custom grids with drag and drop |
| 0009 | Calculator layout | Arithmetic with `Decimal`, live result in the HUD |
| 0010 | Per-app layouts | User-assigned layout per frontmost app |
| 0011 | Volume and brightness gestures | Slider cells; brightness feasibility spike |
| 0012 | More languages | Localization expansion |
| later | Free + trial model | Only if reach requires it; existing buyers are recognised through `AppTransaction` |

## 13. Decisions

| Decision | Made by |
|---|---|
| Mac App Store, sandboxed, public APIs only | PM |
| Native Liquid Glass UI, dark mode, Dock app, starts at login | PM |
| Haptic and sound feedback, on by default, switchable | PM |
| Offline; English and Turkish now, more languages later | PM |
| Trigger is a configurable shortcut, not fn | PM, from spike results |
| Commit with a keyboard key; sticky sessions | PM approved the proposal |
| The display never truncates | PM |
| Adjustable active trackpad area | PM |
| Layouts as data; arithmetic-only calculator and per-app layouts later | PM approved the proposal |
| Volume and brightness gestures in a later RFC | PM |
| One-time paid, no in-app purchases | PM |
| macOS 26 minimum, Swift 6, SwiftUI with AppKit where needed | Development lead |
| Default shortcut ⌃⌥K | Development lead |
| "3×3 standard" read as three columns plus a bottom row | Development lead |
| HUD shows the target app; physical digit keys also edit the number | Development lead |
| Three-module package architecture | Development lead |
| One RFC at a time | Development lead |
| Conventional Commits | Development lead |
| No analytics | Development lead |

## 14. Left to the builder

- Exact HUD dimensions, spacing and animation, within system materials and metrics.
- How the Dock icon presents the disabled state, using the Apple-standard mechanism.
- Settings grouping details.
- Tap thresholds (movement under 0.04 of the trackpad and duration under 0.4 s worked in the spike) and the settle delay; tune them in RFC-0002.
- Whether to close an idle session automatically; decide in RFC-0002.
- Whether the shortcut recorder is built in-house or comes from a small open-source package; decided in RFC-0003 (in-house).
- How the Xcode project is created and maintained; decide in RFC-0001.
