# RFC-0002: Keypad Session

| Field      | Value                                        |
|------------|----------------------------------------------|
| Status     | Implemented                                  |
| Authors    | Claude (development lead), Berkan Aslan (PM) |
| Created    | 2026-10-26                                   |
| Depends on | RFC-0000, RFC-0001                           |

## Summary

Build the product's core: from any app, the shortcut opens a keypad session; taps on the trackpad build a number in a Liquid Glass HUD; a keyboard commit key types the number into the target app and, by default, keeps the session open for the next number. This RFC specifies the domain model, the session state machine, the macOS adapters and the HUD, on top of the verified foundation in RFC-0000 §7 (F1–F11).

Settings UI, onboarding and feedback choices stay in their own RFCs (0003–0005). This RFC uses fixed defaults for everything those RFCs will make configurable.

## Motivation

RFC-0001 produced an empty app. Nothing a user can do with it yet. RFC-0002 is the smallest slice that delivers the product's promise end to end: open, tap, commit, continue, close — in Chrome, in an Electron app, in a native app and in a spreadsheet.

## Design

### Scope

| In scope | Deferred to |
|---|---|
| Shortcut ⌃⌥K (fixed), session lifecycle, capture panel, touch → tap → cell, buffer, HUD, commit, sticky, hand-off, reclaim | — |
| A minimal feedback implementation (haptic on touch-down, system sound on tap — the spike's verified defaults) behind a protocol | RFC-0003 refines patterns, sounds, toggles |
| Fixed defaults: layout `Numpad`, whole-trackpad active area, sticky on | RFC-0004 adds settings and persistence |
| Permission check and the system prompt on first launch | RFC-0005 adds onboarding and recovery |

### Architecture: functional core, imperative shell

The session logic is a pure reducer in `KeypadCore`: it receives events and returns effects. Adapters in `KeypadSystem` turn macOS input into events and carry out effects. The app target wires them together. Every rule in this RFC is therefore testable without a trackpad, a window or a second app.

```
macOS input ──▶ adapters (KeypadSystem) ──SessionEvent──▶ SessionEngine (KeypadCore)
                     ▲                                          │
                     └──────────────── SessionEffect ◀──────────┘
```

### Domain model (`KeypadCore`)

| Type | Responsibility |
|---|---|
| `TrackpadPoint` | A normalized trackpad position, `x` and `y` in `0...1`, origin bottom-left (as `NSTouch.normalizedPosition`). |
| `ActiveArea` | The normalized rectangle of the trackpad that maps onto the layout (RFC-0000 §8.5). `map(_:) -> TrackpadPoint?` returns the point relative to the area, or `nil` outside it. Default: the whole surface. |
| `KeyAction` | What a cell does: `.digit(0...9)`, `.decimalSeparator`, `.backspace`. Later RFCs add operators, commit keys and sliders. |
| `Layout` | `rows`, `columns` and `cells`; each `Cell` has an action, a row, a column and spans. `Layout.numpad` is the built-in 3 × 4 grid `7 8 9 / 4 5 6 / 1 2 3 / 0 , ⌫`. `cell(at:) -> Cell?` hit-tests a point already mapped by the active area. |
| `TouchSample` | One touch event: an opaque touch ID, a phase (`began`, `moved`, `ended`, `cancelled`), a `TrackpadPoint` and a timestamp. |
| `TapRecognizer` | Turns touch samples into `touchDown(Cell)` and `tap(Cell)`. A touch is a tap when it ends within **0.4 s** of beginning and moved less than **0.04** (normalized). Touches are independent, so two fingers can tap in quick succession. A touch that rests longer than 0.4 s never becomes a tap, which lets a palm or a resting finger stay on the surface. The cell is taken from the touch's **starting** point. |
| `EntryBuffer` | The number being entered. `apply(_ action:)`, `isEmpty`, `display(decimalSeparator:)` and `keystrokes`. It behaves like a hardware numpad: no validation, so leading zeros, several separators (e.g. versions or IP addresses) and any length are allowed. Backspace on an empty buffer does nothing. |
| `Keystroke` | An abstract key to type: `.keypadDigit(n)`, `.keypadDecimal`, `.commit(CommitKey)`. `KeypadSystem` maps it to key codes. |
| `CommitKey` | `.return`, `.shiftReturn`, `.keypadEnter`, `.tab`, `.shiftTab`, `.arrow(.left / .right / .up / .down)`. |
| `KeyInput` | A physical key pressed during a session, already classified by the adapter: `.digit(n)`, `.decimalSeparator`, `.deleteBackward`, `.commit(CommitKey)`, `.escape`, `.other`. |
| `AppIdentity` | The target app: process ID, bundle identifier and display name. The icon is loaded by the UI from the process ID. |

### Session state machine

```
            shortcut (frontmost ≠ Keypad)
   idle ───────────────────────────────────▶ capturing ◀──────────────┐
    ▲                                         │   │                    │
    │  Esc · shortcut* · focus lost ·         │   │ commit key         │ reclaimed
    │  target quit · reclaim failed           │   ▼                    │ (sticky)
    └─────────────────────────────────────── committing ──typed──▶ reclaiming
                         typed (not sticky) ◀─┘
```
\* The shortcut while capturing types the pending number without a commit key, then closes.

| State | Event | Effects | Next state |
|---|---|---|---|
| idle | shortcut, frontmost is another app | remember target, `showCapture(target)`, render | capturing |
| idle | shortcut, frontmost is Keypad or none | none | idle |
| idle | shortcut while Secure Input is on (a password field is focused) | `showNotice(.secureInput)` | idle |
| capturing | touch down on a cell | `feedback(.touchDown)`, render highlight | capturing |
| capturing | tap on a cell | apply action, `feedback(.keyAccepted)`, render | capturing |
| capturing | `KeyInput` digit / separator / delete | apply action, render | capturing |
| capturing | `KeyInput.other` | none (swallowed) | capturing |
| capturing | commit key, permission granted | `handOff(target)`, then `type(buffer keystrokes + commit key)`, clear buffer, reset the tap recognizer | committing |
| capturing | commit key, permission missing | render the permission warning | capturing |
| committing | typed, sticky | after delivery: `reclaimFocus` | reclaiming |
| committing | typed, not sticky | after delivery: `hideCapture` | idle |
| reclaiming | reclaimed | render | capturing |
| reclaiming | touch (Keypad is active again before the check ends) | handle it as in *capturing* | capturing |
| reclaiming | reclaim failed | `hideCapture` | idle |
| capturing | shortcut, buffer not empty, permission granted | `handOff`, `type(buffer)`, after delivery `hideCapture` | idle |
| capturing | shortcut, buffer not empty, permission missing | render the permission warning (number kept) | capturing |
| capturing | shortcut, buffer empty | `hideCapture`, hand focus back | idle |
| capturing | Esc | `hideCapture`, hand focus back, buffer discarded | idle |
| any but idle | focus lost — another app activates (⌘Tab, a click, a window chosen in Mission Control, an app opened from Spotlight) or Keypad resigns active — target quit, display configuration changed, user switched | `hideCapture`, buffer discarded | idle |

- **Transient overlays keep the session.** Spotlight and Mission Control take the keyboard and the trackpad without activating another app, and macOS tells Keypad nothing: in QA Keypad stayed active, its panel stayed key and no key or touch reached it. The numpad stays open with its number and works again when the overlay closes. It closes only when the overlay makes another app active (PM, 2026-10-27).
- A commit with an empty buffer still sends its commit key (moving between cells without leaving the session).
- **Delivery wait.** Posted key events are routed to whichever app is key when the window server dispatches them, not when they are posted. So the effects that follow `type` — the reclaim, or the close — wait until the keystrokes can be assumed delivered: **50 ms + 5 ms per keystroke** (QA: Chrome, Excel and Claude, 34 of 34 commits complete). Reclaiming immediately lost every digit still queued to Keypad.
- **Keypad's own keystrokes are tagged** (`eventSourceUserData`). If one still reaches Keypad after the delivery wait, the keyboard monitor discards it and logs it, instead of reading it as input that could commit into another field.
- During *committing* and the delivery wait, Keypad is not active: touches are not delivered (F2) and keys typed on the keyboard go to the target app. The HUD stays visible.
- **Reclaiming** keeps F7's 150 ms check, but Keypad is usually active again after 10–25 ms. A touch that arrives before the check ends proves the reclaim (F2), so it is handled at once instead of being dropped. Keys stay ignored until the check ends: a non-activating panel can be key while Keypad is inactive, and a late key could be Keypad's own until QA confirms the tag reaches it.
- The shortcut is ignored from the commit until the session is capturing again (sticky) or closed (not sticky). An interruption in a sticky session ends it and re-enables the shortcut at once.
- Losing focus never types: the new frontmost app may not be the target (RFC-0000 §5, "never type into the wrong field").

### macOS adapters (`KeypadSystem`)

| Adapter | Core protocol | Implementation notes |
|---|---|---|
| `CarbonHotkey` | — (wired by the composition root; Core never calls it) | `RegisterEventHotKey` with ⌃⌥K. Delivered to our process, so activation counts as user intent (F3). No permission needed. A registration failure (shortcut taken) is logged; `unregister()` exists for RFC-0004's disabled state. |
| `CapturePanelController` | wrapped by the app's `HUDCaptureSurface` (`CaptureSurface`) | Full-screen borderless `NSPanel` with `.nonactivatingPanel`, `canBecomeKey = true`, level `.statusBar`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, on the display under the pointer. `show()` activates Keypad (`NSApp.activate()`, synchronously inside the hotkey callback, F2/F3) and makes the panel key. A faint dim (≈ 10 %) signals that the screen is captured. Hosts the HUD and, on top of it, the touch view. Freezes the pointer with `CGAssociateMouseAndMouseCursorPosition(false)` and restores it on close and on termination. Swallows mouse, scroll and gesture events. Orders Keypad's other windows out while open (F9) and puts them back on close without activating Keypad. |
| `TouchCaptureView` | feeds `TouchSample`s | `allowedTouchTypes = [.indirect]`, `wantsRestingTouches = true`; converts `NSTouch` to `TouchSample`. Works with the built-in trackpad and a Magic Trackpad. |
| `KeyboardClassifier` + `KeyboardMonitor` | feed `KeyInput` | The monitor is a local key-down monitor that swallows keys while a session is open; the classifier maps them to `KeyInput`: top-row and keypad digits; the keypad decimal key and the main-keyboard key that types the current decimal separator; Delete; the commit keys with Shift; Esc. Keys held with ⌘, ⌃ or ⌥, and arrows held with Shift, are `.other`, so a system shortcut such as ⌃↑ never commits and ⇧→ never loses its Shift. Events Keypad posted itself are discarded before classification. |
| `WorkspaceFocusController` | `FocusController` | Hand-off exactly as F6: `NSApp.yieldActivation(to:)`, `target.activate(from: .current)`, wait for `NSWorkspace.didActivateApplicationNotification` for the target's PID, then **60 ms**; time out after **1.5 s** (then close without typing). Reclaim as F7: `NSApp.activate()`, make the panel key, confirm within **150 ms**; otherwise report *reclaim failed*. No deprecated activation APIs (warnings are errors). Reports focus loss (another app activating, or Keypad resigning active outside its own hand-off/reclaim window), target termination, session resign and screen changes — always asynchronously. |
| `CGEventKeystrokeSender` | `KeystrokeSender` | `CGEventSource(stateID: .privateState)`; keypad digits and the keypad decimal key with `.maskNumericPad`; commit keys with their Shift/arrow flags; tagged with `eventSourceUserData`; posted to `.cghidEventTap` after the hand-off; completes after the delivery wait (50 ms + 5 ms per keystroke). |
| `KeyboardLayoutDecimalSeparator` | `DecimalSeparatorProvider` | Reads the character the keypad decimal key produces in the current keyboard layout (`TISCopyCurrentKeyboardLayoutInputSource` + `UCKeyTranslate`), so the HUD shows exactly what will be typed — `,` on a Turkish layout, `.` on a US one. Read on every use, so a layout change shows at once. |
| `SystemFeedbackPlayer` | `FeedbackPlayer` | `.touchDown` → `NSHapticFeedbackManager` `.generic` (on touch-down, F10); `.keyAccepted` → system sound "Tink". Interim until RFC-0003. |
| `PostEventPermission` | `PermissionChecker` | `CGPreflightPostEventAccess`; on first launch `CGRequestPostEventAccess` (F11). |
| `CarbonSecureInputChecker` | `SecureInputChecker` | `IsSecureEventInputEnabled()`, read when the shortcut arrives. |
| `NoticePanelController` | `NoticeSurface` | A small HUD-style panel on the display under the pointer that shows one line for about 2 s, like the system volume HUD: it never activates Keypad, never takes input and ignores the mouse. |

### HUD (`KeypadUI`)

- A SwiftUI view inside the capture panel, centred on the display, built only from system materials: `GlassEffectContainer` with `.glassEffect` cells, system fonts (rounded, monospaced digits for the display), accent colour for the pressed-key highlight.
- Top to bottom: the target app (icon and name) · the number display · the key grid generated from the `Layout` · a hint (it may wrap to two lines in Turkish). The whole HUD sits on a system glass card so its text stays readable over the dimmed app behind it; its width is fixed (328 pt).
- The display never truncates (RFC-0000 §8.2): it spans the HUD's width, scales the text down to 60 % when needed, then wraps and the HUD grows taller.
- The decimal cell shows the separator from `DecimalSeparatorProvider`.
- When the post-event permission is missing, the hint line is replaced by a warning ("Keypad needs Accessibility access to type") and commit keys do nothing: the number stays in the buffer until the user presses Esc. Permission is read when the session opens, so access granted in System Settings applies from the next session.
- Light and dark mode, Reduce Transparency and Reduce Motion come from the system materials; the only animation is the key highlight (≈ 0.18 s), which Reduce Motion turns into an instant change.
- VoiceOver: the HUD's elements carry labels; announcing taps is out of scope.

New strings, each in English and Turkish:

| Key | English | Turkish |
|---|---|---|
| `hud.hint` | Return, Tab or arrows to type · Esc to close | Yazmak için Return, Tab veya oklar · Kapatmak için Esc |
| `hud.permissionMissing` | Keypad needs Accessibility access to type | Keypad'in yazabilmesi için Erişilebilirlik izni gerekiyor |
| `hud.backspace.accessibilityLabel` | Delete | Sil |
| `hud.target.accessibilityLabel` | Typing into %@ | %@ uygulamasına yazılıyor |
| `notice.secureInput` | Keypad can't type while secure input is on, for example in a password field | Güvenli giriş açıkken Keypad yazamaz, örneğin bir şifre alanında |

### Privacy and logging

`os.Logger` with subsystem `io.berkan.keypad` and categories `session`, `focus`, `input`. Logs describe transitions, timings, the target app's name and the number of keystrokes posted; **never** digits, buffer contents or key codes.

### Testing

- **Unit (Swift Testing, `KeypadCore`), written test-first:** active-area mapping and hit-testing at cell boundaries; tap thresholds, multi-touch, resting touches and cancellation; buffer behaviour (no validation, backspace, display with both separators, keystrokes); every row of the state table, including sticky and non-sticky commits, empty-buffer commits, the shortcut with and without a pending number, Esc, focus loss, target termination, hand-off timeout and reclaim failure.
- **Adapters:** kept thin enough that their logic is trivial; covered by the manual QA matrix below.
- **Manual QA matrix (real trackpad):** TextEdit, Notes, Safari address bar, Chrome address bar and a Google Sheets grid (Tab, Return, arrows), an Electron app (e.g. Claude) with repeated commits, Numbers; a full-screen app; two displays; Turkish and US keyboard layouts (separator shown and typed); dark mode; a password field (see Risks).

### QA results (2026-10-26 – 27, PM on a Force Touch trackpad, Turkish layout)

| Check | Result |
|---|---|
| Commits in the Chrome address bar, Excel and Claude, sticky | Complete: 34 of 34 commits after the delivery wait. Before it, digits were lost (`12345` typed `12`, the rest reappeared in the HUD). |
| Reclaim after each commit | The 150 ms check confirmed Keypad active every time. |
| ⌘Tab | Closes the session; the number is discarded. |
| Spotlight, Mission Control | The session stays open (transient overlays, see the state table). |
| Password field | The shortcut arrives; the secure-input notice shows and no session opens. |
| ⌃↑ with the numpad open | Committed as ↑ into the target. Fixed: keys held with ⌘, ⌃ or ⌥ are ignored. Unit-tested; in the follow-up run, the sessions in which ⌃↑ opened Mission Control typed nothing. |
| Look and readability | Approved by the PM. |
| Haptic and sound | Work. The haptic is faint and the sound is an alert-like beep; RFC-0003 revisits both. |
| Deferred to the next QA round (PM, 2026-10-27) | TextEdit, Notes, Safari, Google Sheets, Numbers, a full-screen app, two displays, the US layout, dark mode. Also: Esc and the shortcut with a pending number; screen lock, Notification Center and Control Center with the numpad open; logging out or quitting with a session open (pointer restored); a tap right after a commit; ⇧-arrows; a background app holding secure input; a late keystroke being discarded (the tag reaches Keypad). |

## Alternatives considered

| Alternative | Decision |
|---|---|
| Event-tap trigger or holding fn | Rejected: activation refused (F3), emoji picker (F4). |
| Live typing into the inactive target | Rejected: fails in Chrome (F5). |
| Timer-based hand-off | Rejected: Electron loses keys (F6). |
| A stateful `Session` class mixing logic and AppKit calls | Rejected in favour of a pure reducer: every rule testable without UI. |
| Idle timeout that closes a forgotten session | Not now. Esc and the shortcut close it, and the HUD hint says so. Revisit if QA shows confusion. |
| Validating the number (single separator, no leading zeros) | Rejected: a numpad types what you press; validation would break codes, versions and IP addresses. |
| HID virtual keyboard (`HIDVirtualDevice`) for output | Deferred: needs an entitlement request; the `KeystrokeSender` protocol keeps it possible (RFC-0000 §11). |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Secure Event Input (password fields) suppresses the Carbon hotkey or blocks typing | Decided | Password fields are out of scope for v1, and the PM asked for a notice there instead (2026-10-26). QA showed the shortcut arrives while a password field is focused, so the notice can show. Typing into a password field was not tested. |
| Secure Event Input is system-wide: an app that leaves it on in the background (or the login window after wake) blocks Keypad everywhere | Low | The notice still explains it. RFC-0005 can give the copy a hint about other apps. |
| An app needs longer than 60 ms after activation before it accepts keys | Medium | The delay is one constant; QA matrix; raise it only if an app fails. |
| Reclaim refused by a future macOS | Low | The session closes cleanly instead of hanging; the spike checklist (F7) is part of QA on every macOS beta. |
| Panel does not cover a full-screen app's space | Low | QA matrix includes full-screen; collection behaviour per spike. |
| Two "Keypad" copies registered with the system confuse the permission prompt | Medium (development only) | Keep one build location; documented in AGENTS.md if it recurs. Two running copies also both receive the shortcut and close each other's sessions (QA, 2026-10-27), so quit the old copy before testing a new build. |

## Rollout

1. `KeypadCore` types and `SessionEngine`, test-first.
2. Adapters, one at a time, each wired into the app target as soon as it exists.
3. HUD.
4. Manual QA matrix; tune tap thresholds and the settle delay only if QA shows a need, and record changes here.

Done when every unit test passes, the QA matrix passes, and lint and CI are green. On 2026-10-27 the PM moved the untested part of the matrix to the next QA round (see QA results).

## Open questions

None. Resolved while drafting:

- **Losing focus to another app discards the number** (⌘Tab, a click, a notification that opens its app): confirmed by the PM on 2026-10-26. **Spotlight and Mission Control keep the session** because macOS reports neither to Keypad: PM, 2026-10-27, after QA.
- **Password fields:** out of scope for v1; Keypad shows a short notice there instead of opening (PM, 2026-10-26). QA showed the shortcut arrives, so the notice can show.
