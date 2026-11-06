# RFC-0005: Permission Recovery and Trackpad Pass-Through

| Field      | Value                                        |
|------------|----------------------------------------------|
| Status     | Implemented                                  |
| Authors    | Claude (development lead), Berkan Aslan (PM) |
| Created    | 2026-11-05                                   |
| Depends on | RFC-0000, RFC-0002, RFC-0003, RFC-0004       |

## Summary

The next release, `v0.2.0`, makes four changes:

1. **Build requirement:** the README stops implying that building needs macOS 26 exactly.
2. **Trackpad pass-through:** during a session, the part of the trackpad outside the active area works as a normal trackpad. A click there reaches the app and closes the session.
3. **Automatic recovery:** Keypad notices when the Accessibility permission is granted and can type straight away, so nobody has to quit and relaunch by hand.
4. **Missing-permission HUD:** when the permission is missing, the HUD no longer looks as if it works. Trying to use it shakes the warning, and the HUD leads to the right pane of System Settings.

This RFC narrows the roadmap's RFC-0005 to permission recovery and adds pass-through. First-run onboarding moves to a later RFC.

## Motivation

- **Permission recovery:** the first public install showed that granting Accessibility isn't enough. `CGPreflightPostEventAccess` keeps its first answer for the life of the process, so the HUD still reports a missing permission until Keypad is relaunched (RFC-0004, "Release results"). The README tells users to quit and reopen, which is a workaround.
- **A HUD that looks like it works:** with the permission missing, the keypad opens as usual, accepts taps, plays sounds and builds a number that can never be typed. The only sign of trouble is one line of footnote text.
- **Active area:** a user who gives part of the trackpad to the keypad loses the rest for the whole session, because the pointer is frozen everywhere (RFC-0000 §8.2). Leaving the session is the only way to use the pointer again.
- **Build requirement:** "Requires Xcode 27 on macOS 26" merges two separate facts. macOS 26 is the app's minimum; it isn't the only system that can build it.

## Decisions by the PM (2026-11-05)

1. These four changes ship together in one new version.
2. During a session, the trackpad outside the active area works as usual.
3. A click outside the active area closes the session.
4. Keypad watches the Accessibility permission and reopens itself.
5. With the permission missing, the HUD stays, trying to use it shakes the warning, and the HUD offers a way to the Accessibility settings.

Decision 4 asks for a reopen so that nobody has to relaunch by hand. The feasibility test showed Keypad can achieve that without reopening, so under the rule accepted with this RFC it doesn't reopen (§3).

## Design

### Scope

| In this RFC | Not in this RFC |
|---|---|
| README build requirement | Proving whether Xcode 26 can also build Keypad |
| Pointer, scrolling and clicks outside the active area | Keeping a session open across a click |
| Detecting a grant and confirming it to the user | The first-run onboarding flow and the permission row in Settings (RFC-0000 §8.6): both move to RFC-0013 |
| The missing-permission HUD | Secure Input notice wording; the other follow-ups in RFC-0002 and RFC-0003 |

### Calls by the development lead

The PM asked for the behaviour above. These details are the lead's calls, accepted with this RFC.

| Call | Reason |
|---|---|
| The pointer wakes only after a finger travels outside the active area | A slip next to the keypad must stay harmless (§2) |
| A click discards a pending number | Typing it after the click could put it in the wrong field (§2) |
| No setting for pass-through | The active area is already the control; the default whole-surface area has nothing outside it |
| The capture panel follows the pointer to another display | Touches only reach the panel when the pointer is over it |
| The digits stop working while the permission is missing | A number that can't be typed is the problem being fixed |
| The key grid dims while the permission is missing | It answers "looks like it works" directly |
| Return also opens System Settings in that state | Commit keys have no other use there |
| Version `v0.2.0`, with 1.0 after onboarding | RFC-0004 planned 1.0 after RFC-0005, but onboarding isn't in this release |

### Amendments

The rows for RFC-0000 §7, §12 and §13 and AGENTS.md §6 are already applied. The rest are applied in the branch that changes the behaviour, as AGENTS.md §3 requires.

| Where | Today | After |
|---|---|---|
| RFC-0000 §5 | Keypad fails if it "loses a typed number" | The same, except that a deliberate click outside the active area discards the number, as Esc does |
| RFC-0000 §7 | F1–F11 | F12–F20 from the feasibility test |
| RFC-0000 §8.2 | The pointer freezes; clicks, scrolls and gestures are swallowed | True in keypad mode only (§2) |
| RFC-0000 §8.5 | Touches outside the active area are ignored | They work as a normal trackpad once the pointer wakes (§2) |
| RFC-0000 §8.6 | Polling `CGPreflightPostEventAccess()` | Replaced by §3; the onboarding steps move to RFC-0013 |
| RFC-0000 §12 | 0005 Onboarding and permissions; 1.0 after it | 0005 is this RFC; 0013 First-run onboarding; 1.0 after 0013 |
| RFC-0000 §13 | — | The PM's decisions above |
| RFC-0002, HUD | Commit keys do nothing; access applies from the next session | A note pointing to §4 of this RFC |
| AGENTS.md §6 | F1–F11 | F1–F20 |
| Glossary | Active area; Capture panel | Updated, with new entries for *keypad mode* and *pointer mode* |
| README | First launch, Features, FAQ | Quit-and-reopen steps removed; pass-through described |

### 1. Build requirement

`README.md`, "Build from source", changes from:

> Requires Xcode 27 on macOS 26.

to:

> Requires Xcode 27, which runs on macOS 26.6 or later.

Xcode 27.0 declares macOS 26.6 as its minimum, and CI builds it on macOS 27. "Requires macOS 26 Tahoe or later" in the Install section stays, because that line is about running the app.

### 2. Trackpad pass-through

**Keypad mode and pointer mode.** A session always has one of two modes.

| | Keypad mode | Pointer mode |
|---|---|---|
| Pointer | Frozen | Moves |
| Clicks, scrolling, gestures | Swallowed | Reach whatever is under the pointer |
| Taps in the active area | Enter digits | Enter digits, and return to keypad mode |
| Footer | The usual hint | "Clicking closes Keypad · Tap the keypad to continue" |

Every session opens in keypad mode.

**Rules:**

| Mode | What happens | Result |
|---|---|---|
| Keypad | A finger lands in the active area | As today |
| Keypad | A finger lands outside and lifts without travelling, even after a press | Ignored, as today |
| Keypad | A finger that landed outside travels the tap movement limit (0.04 of the trackpad), with no finger in the active area and without having stayed down through a tap | Pointer mode |
| Pointer | A finger lands outside | Normal trackpad use |
| Pointer | A finger lands in the active area | Keypad mode: the pointer freezes where it is, and the touch counts as a tap |
| Pointer | The user clicks | The click reaches the app under the pointer, and the session closes (below) |
| Either | A commit key, Esc or the shortcut | As today; a sticky session resumes in keypad mode |

**A contact belongs to where it landed.** A finger that slides from outside into the active area keeps moving the pointer. A finger that slides out of the active area stays a keypad contact, and the movement cancels its tap, as it does today. A finger that stays down through a tap is resting, so it can't wake the pointer however far it drifts.

**Why the pointer has to wake first.** With tap to click turned on, a light tap next to the keypad is a click. If that closed the session, every slip would lose the number. Asking for travel first keeps slips harmless, and it costs little: the pointer starts frozen, so someone who wants to click something nearly always has to move it first.

**A click closes the session.** In pointer mode, Keypad watches for a mouse-down that reaches another app, using a global `NSEvent` monitor, which needs no permission. The click itself closes the session, even if no app activates. Every click that got through in the test activated its app within 20 ms, but clicks on other spots with the pointer frozen often didn't (F16), so activation alone isn't enough. The existing rule stays as a second trigger. If Keypad is still the active app just after the close, it hands focus to the target app, so the keyboard isn't left with no window. Keypad can't keep the trackpad after a click, because touches only arrive while Keypad is active (F2).

**A click can miss.** In the test, 2 of 8 clicks stayed on the panel: a press 28 ms after the finger landed, and a click with no touch reported. The session stays open and nothing else happens, so the user clicks again (F16). Light taps have the thinnest evidence, one through and one missed, so QA repeats them.

**The HUD stays solid.** A click over the HUD stays on the panel, so it can't fire a control hidden behind the HUD. Nothing happens and the session stays open, because the pointer can look as if it could press a key.

**Scrolling** works once the pointer is awake. A scroll that starts while the pointer is asleep wakes it, but that scroll stays with the panel and moves nothing; the next one works. Momentum can stop early, when the panel takes mouse input back (F17).

**A pending number is discarded,** as with Esc. Keypad can't type it first: by the time Keypad knows about the click, focus has moved, and the number could land in the wrong field, which is the worse failure in RFC-0000 §5. The pointer-mode footer warns the user before they click.

**With the whole trackpad as the active area,** the default, nothing is outside it and nothing changes. The active area is the only control; there is no new setting.

**How it works:**

- **Pointer:** `CGAssociateMouseAndMouseCursorPosition(1)` in pointer mode and `(0)` in keypad mode. Keypad already uses this call. The travel limit means the pointer starts moving slightly late; QA tunes it if that feels like a jump (F14).
- **Mouse input:** AppKit attaches a first touch to the view under the pointer, using the same hit detection as mouse events. A panel that ignores mouse events when a finger lands doesn't get that touch (F12), while a touch already attached stays attached until every finger lifts (F13). So the panel sets `ignoresMouseEvents = true` only while a finger that landed outside is down in pointer mode, and clears it after the last finger lifts. The panel can't see a finger that lands while it ignores mouse events, so a lift after a single finger travelled ends pass-through at once: nothing can follow that touch. A grace period of 150 ms follows only a stationary touch, whose tap-to-click click arrives within about 10 ms of the lift (F15), or a touch with several fingers, where momentum can follow. A key tapped inside that window is missed.
- **Another display:** touches stop reaching the panel if the pointer leaves it. When pass-through ends with the pointer on a different display, the capture panel and its HUD move to that display.
- **Layers:** the rules live in `KeypadCore`, as engine state and new effects, so they can be tested without a trackpad. The timer and the AppKit and CoreGraphics calls stay in `CapturePanelController`. The panel's close path restores everything, as it does today.

An external mouse stays frozen in keypad mode, as it does now.

### 3. Permission watching

**The signal.** No public API announces a permission change, so Keypad polls. The feasibility test compared the candidates on macOS 27:

| Candidate | Result |
|---|---|
| `CGPreflightPostEventAccess` | Never changed while the process ran, even with the permission on |
| `AXIsProcessTrusted` | Followed the switch within a second, in both directions, 5 of 5 times, with no prompt |
| Creating an event tap as a probe | Also followed the switch, 4 of 4 times, but does more than a status check needs |
| The `com.apple.accessibility.api` distributed notification | Undocumented, so ruled out by AGENTS.md §6 |

Keypad uses `AXIsProcessTrusted()`: `PostEventPermission.canPostEvents` reads it instead of `CGPreflightPostEventAccess`. `CGRequestPostEventAccess` stays as the way to ask. Keypad polls once a second, only while the permission is missing, and stops when it is granted. A Keypad that has the permission runs no timer.

**No reopen.** A posted key reached another app right after the grant and stopped right after the switch went off (F19). The stale check was the whole problem, so Keypad simply keeps running.

**The flow:**

1. At launch, the permission is missing. Keypad asks the system as it does today (F11) and starts watching.
2. The user turns Keypad on in System Settings.
3. Within about a second, Keypad sees the grant, stops watching and shows the notice "Keypad can now type into other apps". The next session has no warning.

**Revoking.** Each session reads the signal when it opens, so a revoked permission shows the warning and starts the watcher again. A session that is already open keeps its state until it closes.

**Layers:** a `PermissionWatcher` protocol in `KeypadCore` with a `KeypadSystem` adapter. The decision logic stays in Core so tests can drive it with a fake clock.

### 4. Missing-permission HUD

The HUD opens as usual, with these differences.

| Part | Behaviour while the permission is missing |
|---|---|
| Pointer | Moves for the whole session, because it has to reach the button. There are no pointer-mode rules in this state. |
| Key grid | Dimmed, in the system's disabled style |
| Footer | The warning "Keypad needs Accessibility access to type", with an "Open System Settings" button below it |
| Tap on a cell | No digit, no sound, no haptic; the warning shakes |
| Digit, decimal, Delete, Tab, arrow keys | No effect on the number; the warning shakes |
| Return, ⇧Return or keypad Enter | Same as the button |
| Esc, the shortcut | Close the session, as today |

Clicks anywhere but the button stay swallowed. They can't close the session here, because a tap with tap to click turned on is also a click, and it has to shake.

**The shake.** A short horizontal shake of the warning, about 0.4 s, like a wrong password at the macOS login window. Each attempt restarts it. With Reduce Motion on, the warning doesn't move; it briefly turns system red instead. VoiceOver announces the warning.

**The button** opens `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` and closes the session. The watcher from §3 is already running, so a grant then takes effect with no further steps.

**Layers:** `HUDState` gains a counter that the engine increases on each attempt; the view uses it as the animation trigger. The buffer stays empty, so the permission checks in the commit and shortcut paths reduce to these rules. A new session event and effect carry the request to open System Settings, and `PermissionChecker` gains the adapter call. The capture panel skips its pointer freeze in this state, and the touch view lets clicks reach the button.

### Strings

New strings, each in English and Turkish:

| Key | English | Turkish |
|---|---|---|
| `hud.permission.openSettings` | Open System Settings | Sistem Ayarları'nı Aç |
| `hud.pointerHint` | Clicking closes Keypad · Tap the keypad to continue | Tıklamak Keypad'i kapatır · Devam etmek için tuşlara dokunun |
| `notice.permissionGranted` | Keypad can now type into other apps | Keypad artık diğer uygulamalara yazabilir |

### Feasibility test

These questions needed a real trackpad and the real permission switch, so a throwaway sandboxed build, signed with the project's team, answered them before the implementation plan was written (2026-11-06, macOS 27, tap to click on). The findings are in RFC-0000 §7.

| # | Question | Result |
|---|---|---|
| T1 | Does the capture view get a touch when the panel already ignores mouse events as the finger lands? | No, in 43 clicks, as expected (F12) |
| T2 | With a finger down, does setting `ignoresMouseEvents` keep touches arriving, and do a press, a drag and a two-finger scroll reach the app below? | Yes (F13), with the limits in §2 (F16, F17). The planned fallback isn't needed. |
| T3 | Can the pointer be released and frozen again by touches without a jump, while touches keep arriving? | Freezing held 23 of 23 times. Logs of 5 wakes show no stored movement, but the tester reported a jump, so QA checks it (F14). |
| T4 | When does a tap-to-click click arrive relative to the touch ending, and how long must the grace period be? Does momentum scrolling survive? | Clicks arrive 3–9 ms after the lift, and 150 ms worked (F15). Momentum ran to the end in 2 of 3 flicks (F17). |
| T5 | Which of the §3 candidates follows the System Settings switch, in both directions, without a new prompt? | `AXIsProcessTrusted` and the event-tap probe (F18) |
| T6 | Does a posted key reach another app right after the grant, with no relaunch? | Yes, so Keypad doesn't reopen (F19) |
| T7 | Does the reopen work from `/Applications` in a sandboxed, hardened, Developer ID build, keeping the grant and leaving one copy running? | No longer needed. An Apple Development build reopened from `/Applications` in about 100 ms and kept the grant; the Developer ID check was dropped. |
| T8 | Does the settings link open the Accessibility pane on macOS 27, and on macOS 26 if a test machine is available? | Yes on macOS 27 (F20). macOS 26 is left to QA. |

The test didn't exercise the capture panel following the pointer to another display, so QA covers it.

### Testing

Swift Testing, with a failing test first (AGENTS.md §11):

- **Modes:** every row of the rules table in §2, contact ownership, a resting finger outside while tapping inside, and a commit from pointer mode.
- **Click:** a click in pointer mode closes the session and discards the buffer, with or without an activation; a click in keypad mode doesn't.
- **Permission HUD:** each row of the table in §4, with the buffer staying empty and the shake counter rising.
- **Recovery:** a grant when idle, the watcher stopping after a grant, and a revoke seen when a session opens.
- **Strings:** the existing localization tests cover the new keys.

Manual QA on a real trackpad:

- Tap to click on and off, with taps right at the edge of the active area, and a key tapped as fast as possible after moving the pointer.
- A thumb resting outside the area through a long run of numbers.
- A quick re-clutch outside the area followed by a physical click, and a click on the HUD.
- Clicks, a drag, a two-finger scroll and a Mission Control swipe in pointer mode, with light taps repeated many times.
- Whether the pointer seems to jump when it wakes, and whether the travel limit needs tuning.
- Pass-through in Excel, Chrome and an Electron app.
- Two displays, including the panel following the pointer and a commit with the pointer on the other display, full-screen apps, and the active area in each corner.
- Revoking and granting, removing Keypad from the Accessibility list, a grant made through the system prompt, and an unsigned build.
- `AXIsProcessTrusted` and the settings link on macOS 26, if a test machine is available.
- VoiceOver, Reduce Motion and the Turkish footer, which may wrap to two lines.

### Final review

A fresh reviewer read the whole change before it merged. It found three problems the tests had missed, all fixed before release:

- A key tapped right after moving the pointer could be lost, because the panel can't see a finger land during the grace period (F12). The grace period now follows only stationary and several-finger touches.
- A thumb resting outside the area could wake the pointer between taps. A finger that stays down through a tap now counts as resting.
- A click on the HUD could reach a control hidden behind it. The HUD now keeps the mouse.

A thumb that drifts before the first tap can still wake the pointer; `NSTouch.isResting` isn't used yet.

### QA results (2026-11-06, the PM on a Force Touch trackpad, tap to click on)

The PM stopped the release QA at step 2 of 18 and asked to release without it. These results come from an earlier hands-on check of a separate build, before the version bump.

| Check | Result |
|---|---|
| Typing right after a grant, with no relaunch | Pass, confirmed by the log: the same process typed into TextEdit after the grant |
| Commit, hand-off and reclaim | Pass, confirmed by the log: hand-offs took about 70 ms and every reclaim was active |
| Dimmed keys, the shake, the settings button, the grant notice | Pass (PM) |
| A stray tap outside the area | Pass (PM) |
| Pointer wake with no jump, a fast tap after a move, a resting thumb, a click on the HUD, a firm click | Pass (PM), with a session open for each check |
| Light tap in pointer mode | Thin: one try of about a second, on top of one through and one missed in the feasibility test |
| Resting thumb | One thing to watch: that session ended because another app activated, not through Esc; the cause is unknown |
| Not run | A quick re-clutch, scrolling and a right-click in the real app, a Mission Control swipe in pointer mode, a second display, tap to click off, Chrome and Excel with this build, Esc and the shortcut with a pending number, a tap right after a commit, screen lock and quitting with a session open, revoking in the real app, removing Keypad from the list, macOS 26, an unsigned build, VoiceOver, Reduce Motion, the Turkish footer |
| Still deferred | Everything deferred in RFC-0002 and RFC-0003 |

### Release results

| Check | Result |
|---|---|
| Automated checks | `swift test` and lint pass; CI passed on the release commit |
| Dry run | Notarization accepted, and the DMG verified, before the tag was pushed |
| `v0.2.0` (2026-11-06) | Published with `scripts/release.sh`. The published DMG was downloaded again: its SHA-256 equals GitHub's digest and the cask, its ticket validates, Gatekeeper reports a notarized Developer ID source, and the app inside is 0.2.0, signed by the team and sandboxed. |

## Alternatives considered

| Alternative | Decision |
|---|---|
| Keep the session open after a click by taking focus back | Not now. The PM chose to close it. Reclaiming is proven after a commit (F7) but not after a real click, and it would have to wait for a drag to finish. |
| Pointer only, with clicks swallowed | Rejected: a pointer that can't click looks as if it works. |
| Post a synthetic click after closing | Rejected. Keypad promises to post only the number and the commit key, and a drag would still fail. |
| Close the session on any click outside, with no travel | Rejected. With tap to click on, a slip next to the keypad would lose the number. |
| Type the pending number when a click arrives | Rejected. It could land in the wrong field. |
| A setting for pass-through | Not now (KISS). Revisit if QA finds accidental closes. |
| A separate permission window instead of the HUD | Rejected. The PM asked to keep the HUD, and a shake on the real attempt teaches the problem where it happens. |
| Return as the only route to System Settings | Rejected. A visible button is easier to find, and the pointer can be released here at no cost. |
| Reopen Keypad after a grant | Rejected after the test. Posting works straight away, so a reopen would only add a flicker. It worked in about 100 ms, so it stays available if a future macOS needs it. |
| Reopen whenever System Settings loses focus | Rejected after the test. `AXIsProcessTrusted` makes it unnecessary. |
| Close the session only when an app activates | Rejected after the test. Some clicks reach an app without activating it (F16). |
| A helper process to read a fresh permission answer | Rejected. It adds a target, and `AXIsProcessTrusted` already gives a live answer. |
| Three separate RFCs | Rejected. The items ship together and change the same session and panel code. |
| All of the roadmap's RFC-0005, with onboarding | Deferred. The recovery work stands alone, and onboarding deserves its own design. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| A click stays on the panel while it switches (2 of 8 in the test) | Medium | The session stays open and the next click works; QA repeats light taps |
| A key tapped during the grace period is missed, because the panel can't see it (F12) | Low | The grace period follows only stationary and several-finger touches, not a pointer move |
| A deliberate click loses a number | Medium | The footer warns before the click; the pointer needs travel first |
| The pointer ends up on a display the panel isn't on | Medium | The panel follows the pointer; QA on two displays |
| `AXIsProcessTrusted` behaves differently on macOS 26 or a future macOS | Low to medium | Only macOS 27 was tested. If it goes stale, Keypad falls back to today's behaviour: relaunching reads a fresh answer. |
| Removing Keypad from the list isn't seen, as some developers report | Low | QA checks it; commits would then type nothing, as they do today |
| A future macOS changes the settings link | Low | Fall back to opening System Settings |
| Polling costs battery | Low | It runs only while the permission is missing |

## Rollout

1. The PM accepts this RFC and answers the open questions. Done on 2026-11-05.
2. Run the feasibility test and record the findings. If a result changes this design, update the RFC and bring it back to the PM. Done on 2026-11-06, and the PM confirmed the changes the same day; they are listed under "Open questions".
3. Write the plan in `docs/plans/`.
4. Implement in this order, one branch each: the missing-permission HUD (§4), permission watching (§3), then pass-through (§2). The HUD comes first because it is the most self-contained. The README fix (§1) can land at any point.
5. Run the QA above, plus the rounds deferred in RFC-0002 and RFC-0003. The PM stopped this on 2026-11-06 and asked to release without it; see "QA results".
6. Release `v0.2.0` with `scripts/release.sh`, then record the results here and mark this RFC Implemented. Done on 2026-11-06.

## Open questions

Accepted by the PM on 2026-11-05 with the drafted defaults:

1. **Version:** ship as `v0.2.0`, and move 1.0 to after onboarding (RFC-0013).
2. **Pending number:** a click in pointer mode discards it.
3. **If T2 fails:** ship the fallback, as long as T3 passes. T2 passed, so this no longer applies.

The feasibility test settled the grace period (150 ms) and the permission signal (`AXIsProcessTrusted`). It also changed the design, and the PM confirmed these changes on 2026-11-06:

1. **No reopen:** Keypad keeps running after a grant (§3).
2. **Closing on the click:** the click itself closes the session, not the app activating (§2).
3. **First scroll:** a scroll that starts while the pointer is asleep only wakes it (§2).

Left to QA: whether the pointer's start feels like a jump, and how reliably light taps get through.
