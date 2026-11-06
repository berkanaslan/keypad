# RFC-0005 Permission Recovery and Trackpad Pass-Through Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `v0.2.0`: the README build line is fixed, the missing-permission HUD stops looking as if it works, Keypad recovers from a grant with no relaunch, and the trackpad outside the active area works normally during a session.

**Architecture:** All rules live in `KeypadCore` as pure engine state and new effects, tested without a trackpad. `KeypadSystem` adapters carry them out. `KeypadUI` renders them, and the app target only wires them together. A new `PointerRouter` owns the pass-through rules, and a new `PermissionRecovery` owns the watching rules.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Swift Testing. No new dependencies.

**Spec:** `docs/rfcs/0005-permission-recovery-and-trackpad-pass-through.md` (foundation: `docs/rfcs/0000-vision-and-architecture.md` §7, F1–F20)

## Global Constraints

- Target macOS 26 and later. Public APIs only. The only entitlement stays `com.apple.security.app-sandbox`. No network access.
- Never import AppKit, Carbon or SwiftUI in `KeypadCore`. Put every system service behind a Core protocol.
- Every new user-facing string goes in a String Catalog with English and Turkish values, in the same commit, with an entry in `LocalizationTests`.
- Write the failing test first. Warnings are errors.
- Before each branch merges: `swift format lint --recursive --strict Packages Keypad` prints nothing, and `swift test --package-path Packages/KeypadKit` passes.
- Branch from `develop`. Squash each branch into one Conventional Commit whose body lists the work, then merge with `--no-ff`. Never push without the PM's OK.
- A signed build must print `TeamIdentifier=4HYL3L2W4Z` (AGENTS.md §10). Anything else is a stop.
- When behaviour or terms change, update the RFCs and the glossary in the same branch.
- Quit the installed Keypad before running a development build: two copies both receive the shortcut (RFC-0002).

## Review Focus

1. A thumb or palm resting outside the area while the user taps the keypad must not wake the pointer. Test: Task 5, `restingFingerOutsideStaysAsleepWhileTapping`.
2. A finger landing in the area right after pointer use must end pass-through at once, so the tap-to-click click that follows can't reach the app. Test: Task 5, `landingInTheAreaEndsPassThroughAtOnce`.
3. Whichever way a session ends in pointer mode, the next one must open with the pointer frozen. Test: Task 6, `everyExitLeavesTheNextSessionInKeypadMode`.
4. Pressing the shortcut repeatedly while the permission is missing must not stack watchers or notices. Test: Task 4, `watchingTwiceKeepsOneWatcher`.
5. A late "Open System Settings" press after the session closed must do nothing. Test: Task 2, `settingsRequestAfterCloseDoesNothing`.

---

## Branches

| Branch | Tasks |
|---|---|
| `docs/readme-build-requirement` | 1 |
| `feature/missing-permission-hud` | 2, 3 |
| `feature/permission-watching` | 4 |
| `feature/trackpad-pass-through` | 5, 6, 7 |
| `chore/release-0.2.0` | 8 |

Paths below start at `Packages/KeypadKit/` unless they name a top-level folder.

### Task 1: README build requirement

**Files:**
- Modify: `README.md:93`

- [ ] **Step 1: Replace the line**

`Requires Xcode 27 on macOS 26.` becomes `Requires Xcode 27, which runs on macOS 26.6 or later.` Leave "Requires macOS 26 Tahoe or later" in the Install section as it is.

- [ ] **Step 2: Commit and merge**

Commit `docs(readme): state the Xcode requirement correctly`, then merge with `--no-ff`.

### Task 2: Core rules for a missing permission

**Files:**
- Modify: `Sources/KeypadCore/Session/SessionEffect.swift`, `SessionEvent.swift`, `SessionEngine.swift`, `SessionRunner.swift`, `SystemServices.swift`
- Modify: `Sources/KeypadSystem/Permissions/PostEventPermission.swift`
- Test: `Tests/KeypadCoreTests/SessionEngineTests.swift`, `SessionRunnerTests.swift`, `Fakes.swift`
- Create: `Tests/KeypadSystemTests/PostEventPermissionTests.swift`

**Interfaces:**
- Produces:
  - `HUDState.permissionNudges: Int`, a new init parameter defaulting to `0`
  - `SessionEvent.permissionSettingsRequested`
  - `SessionEffect.openPermissionSettings`
  - `PermissionChecker.openPermissionSettings()`
  - `SessionRunner.openPermissionSettings()`
  - `PostEventPermission.settingsLink: URL`

- [ ] **Step 1: Write the failing tests**

Delete `shortcutWithPendingNumberWaitsForPermission` and `missingPermissionBlocksCommitAndWarns`: a number can no longer build up in this state. Add to `SessionEngineTests`:

```swift
@Test mutating func tapWhilePermissionIsMissingOnlyNudges() {
    open(&engine, canPost: false)
    let effects = tap(&engine, x: 0.1, y: 0.95)
    let hud = lastRender(in: effects)
    #expect(hud?.buffer.isEmpty == true)
    #expect(hud?.permissionNudges == 1)
    #expect(hud?.highlightedCell == nil)
    #expect(!effects.contains(.feedback(.touchDown)))
    #expect(!effects.contains(.feedback(.keyAccepted)))
}

@Test(arguments: [
    KeyInput.digit(7), .decimalSeparator, .deleteBackward, .commit(.tab), .commit(.shiftTab), .commit(.arrow(.up)),
])
mutating func keyWhilePermissionIsMissingOnlyNudges(key: KeyInput) {
    open(&engine, canPost: false)
    let hud = lastRender(in: engine.handle(.key(key)))
    #expect(hud?.buffer.isEmpty == true)
    #expect(hud?.permissionNudges == 1)
    #expect(engine.state == .capturing)
}

@Test(arguments: [CommitKey.returnKey, .shiftReturn, .keypadEnter])
mutating func returnOpensSettingsWhilePermissionIsMissing(key: CommitKey) {
    open(&engine, canPost: false)
    #expect(engine.handle(.key(.commit(key))) == [.hideCapture(returnFocusTo: nil), .openPermissionSettings])
    #expect(engine.state == .idle)
}
```

Also add:
- `nudgesCountUpAndResetWithTheNextSession`: two taps give `permissionNudges == 2`; after Esc and reopening, the first render gives `0`.
- `settingsRequestClosesAndOpensSettings`: `.permissionSettingsRequested` while capturing gives the same effects as Return.
- `settingsRequestAfterCloseDoesNothing`: the same event while idle gives `[]`.
- `settingsRequestWithThePermissionDoesNothing`: with `canPost: true` it gives `[]` and the state stays `.capturing`.

Add to `FakePermission`: `private(set) var settingsOpens = 0` and `func openPermissionSettings() { settingsOpens += 1 }`.

Add to `SessionRunnerTests`: `openPermissionSettingsReachesTheChecker`, with `permission.canPostEvents = false`, `shortcutPressed()`, `openPermissionSettings()`, then `#expect(harness.permission.settingsOpens == 1)` and `#expect(harness.surface.log.last == "hide")`.

Add `PostEventPermissionTests.settingsLinkOpensAccessibility`: `settingsLink.absoluteString == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit --filter "SessionEngineTests|SessionRunnerTests|PostEventPermissionTests"`
Expected: FAIL to compile on `permissionNudges` and `openPermissionSettings`.

- [ ] **Step 3: Implement the rules**

In `SessionEngine`, add `private var permissionNudges = 0`, reset in `open`. Handle the missing permission at the top of `handleTouch` and `handleKey`:
- `.touchDown` returns `[]`; `.tap` on a cell nudges.
- Digit, decimal, Delete, Tab, ⇧Tab and arrows nudge. A nudge raises the counter and returns one `.render`.
- `.returnKey`, `.shiftReturn` and `.keypadEnter` return `close(returnFocusTo: nil) + [.openPermissionSettings]`.
- `.escape` and `.other` behave as they do today.

Remove the `guard canPostEvents` lines from `commit` and `closeByShortcut`: the buffer is now always empty in this state.

In `handle`, add `case (.capturing, .permissionSettingsRequested)`, which does the same as Return when `canPostEvents` is false and returns `[]` otherwise.

In `SessionRunner`, add `public func openPermissionSettings()`, which sends the event, and perform the effect through `permission.openPermissionSettings()`.

In `PostEventPermission`, add `static let settingsLink` and implement `openPermissionSettings()` with `NSWorkspace.shared.open`. If that returns `false`, open `/System/Applications/System Settings.app`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(session): nudge instead of typing while the permission is missing`

### Task 3: Missing-permission HUD

**Files:**
- Modify: `Sources/KeypadUI/HUD/KeypadHUDModel.swift`, `KeypadHUDView.swift`
- Modify: `Sources/KeypadUI/Resources/Localizable.xcstrings`
- Modify: `Sources/KeypadSystem/Capture/CapturePanelController.swift`, `TouchCaptureView.swift`
- Modify: `Keypad/HUDCaptureSurface.swift`, `Keypad/AppDelegate.swift`
- Modify: `docs/rfcs/0002-keypad-session.md`
- Test: `Tests/KeypadUITests/KeypadHUDModelTests.swift`, `LocalizationTests.swift`

**Interfaces:**
- Consumes: `HUDState.permissionNudges`, `SessionRunner.openPermissionSettings()`
- Produces:
  - `KeypadHUDModel.isWarningEmphasized: Bool`
  - `KeypadHUDModel.onOpenSettings: (@MainActor () -> Void)?`
  - `KeypadHUDModel.onSettingsButtonFrame: (@MainActor (CGRect?) -> Void)?`
  - `CapturePanelController.show(freezesPointer: Bool)`
  - `CapturePanelController.setClickThrough(_ rect: CGRect?)`, with `rect` in the content view's coordinates
  - `HUDCaptureSurface.onOpenSettings: (@MainActor () -> Void)?`

- [ ] **Step 1: Write the failing tests**

Give the `state(...)` helper in `KeypadHUDModelTests` a `nudges: Int = 0` parameter, then add:

```swift
@Test func aNudgeEmphasizesTheWarningBriefly() async {
    let model = KeypadHUDModel(warningEmphasis: .milliseconds(20))
    model.apply(state(highlighting: nil, nudges: 1))
    #expect(model.isWarningEmphasized)
    await wait { !model.isWarningEmphasized }
    #expect(!model.isWarningEmphasized)
}

@Test func anUnchangedNudgeCountEmphasizesNothing() async {
    let model = KeypadHUDModel(warningEmphasis: .milliseconds(20))
    model.apply(state(highlighting: nil, nudges: 1))
    await wait { !model.isWarningEmphasized }
    model.apply(state(highlighting: nil, nudges: 1))
    #expect(!model.isWarningEmphasized)
}
```

Add to `LocalizationTests`: `("hud.permission.openSettings", "Sistem Ayarları'nı Aç")`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit --filter "KeypadHUDModelTests|LocalizationTests"`
Expected: FAIL.

- [ ] **Step 3: Implement the model and the string**

Add `warningEmphasis: Duration = .milliseconds(400)` to the model's init. `apply` sets `isWarningEmphasized` when `permissionNudges` rises and clears it after that duration, in the same way as `highlightedCell`.

Add `hud.permission.openSettings` to the catalog: English "Open System Settings", Turkish "Sistem Ayarları'nı Aç".

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit --filter "KeypadHUDModelTests|LocalizationTests"`
Expected: PASS.

- [ ] **Step 5: Build the HUD**

In `KeypadHUDView`:
- The key grid takes `.opacity(0.4)` while `showsPermissionWarning` is true.
- `Footer` shows the warning with a system `Button` for `hud.permission.openSettings` below it, calling `model.onOpenSettings`. The button reports its frame to `onSettingsButtonFrame` with `onGeometryChange`, and reports `nil` when it goes away.
- With Reduce Motion off, the warning shakes horizontally for about 0.4 s, using `keyframeAnimator` triggered by `permissionNudges`. With it on, the warning doesn't move and uses `.red` while `isWarningEmphasized` is true.
- On each new nudge, post the warning text with `AccessibilityNotification.Announcement`.

- [ ] **Step 6: Let the pointer reach the button**

`CapturePanelController.show(freezesPointer:)` skips `CGAssociateMouseAndMouseCursorPosition(0)` when `false`. `hide()` is unchanged.

`TouchCaptureView` gains `var clickThroughRect: NSRect?`. Its `hitTest(_:)` returns `nil` inside that rect, so only the button gets the click: touches over the rest of the HUD must still reach this view, or taps there wouldn't shake. `setClickThrough` converts the rect with `content.convert(_:to:)`.

`HUDCaptureSurface.show` passes `freezesPointer: !hud.showsPermissionWarning`, and wires `model.onOpenSettings` and `model.onSettingsButtonFrame`. `AppDelegate` sets `surface.onOpenSettings = { [weak runner] in runner?.openPermissionSettings() }`.

- [ ] **Step 7: Update the docs**

Add one line to the HUD section of `docs/rfcs/0002-keypad-session.md`, after the paragraph on the missing permission: "RFC-0005 §4 replaces this behaviour."

- [ ] **Step 8: Verify on a signed build**

Run the signed build and team check from AGENTS.md §10. A development build has no grant, so the warning appears. Check each row of the table in RFC-0005 §4, then Reduce Motion, and that a click on the button opens the Accessibility list. Tapping with the pointer over the HUD must still shake.

- [ ] **Step 9: Commit, squash and merge**

`feat(hud): make a missing permission obvious and link to the settings`

### Task 4: Permission recovery

**Files:**
- Create: `Sources/KeypadCore/Session/PermissionRecovery.swift`
- Create: `Sources/KeypadSystem/Permissions/TimerPermissionWatcher.swift`
- Modify: `Sources/KeypadCore/Session/SystemServices.swift`, `SessionEffect.swift`, `SessionRunner.swift`
- Modify: `Sources/KeypadSystem/Permissions/PostEventPermission.swift`
- Modify: `Sources/KeypadUI/Notice/NoticeView.swift`, `Sources/KeypadUI/Resources/Localizable.xcstrings`
- Modify: `Keypad/AppDelegate.swift`, `README.md`, `docs/rfcs/0000-vision-and-architecture.md`
- Test: create `Tests/KeypadCoreTests/PermissionRecoveryTests.swift`; modify `Fakes.swift`, `SessionRunnerTests.swift`, `Tests/KeypadUITests/LocalizationTests.swift`

**Interfaces:**
- Produces:

```swift
@MainActor public protocol PermissionWatcher: AnyObject {
    /// Calls `tick` about once a second until `stop()`.
    func start(tick: @escaping @MainActor () -> Void)
    func stop()
}

@MainActor public final class PermissionRecovery {
    public init(permission: PermissionChecker, watcher: PermissionWatcher, notices: NoticeSurface)
    /// Starts watching when the permission is missing; does nothing while already watching.
    public func watchIfMissing()
}
```

Also `Notice.permissionGranted` and `SessionRunner.onPermissionMissing: (@MainActor () -> Void)?`.

- [ ] **Step 1: Write the failing tests**

Add `FakeWatcher` to `Fakes.swift`: it counts `startCount` and `stopCount`, keeps the `tick` closure and offers `fire()`.

```swift
@Test func startsWatchingOnlyWhenMissing() { ... }      // canPostEvents true: startCount == 0
@Test func watchingTwiceKeepsOneWatcher() { ... }       // two calls while missing: startCount == 1
@Test func aTickWithoutAGrantKeepsWatching() { ... }    // fire(): stopCount == 0, notices.shown == []
@Test func aGrantStopsWatchingAndTellsTheUserOnce() {
    permission.canPostEvents = false
    recovery.watchIfMissing()
    permission.canPostEvents = true
    watcher.fire()
    #expect(watcher.stopCount == 1)
    #expect(notices.shown == [.permissionGranted])
}
@Test func aRevokeAfterAGrantWatchesAgain() { ... }     // grant, revoke, watchIfMissing: startCount == 2
```

Add `shortcutReportsAMissingPermission` to `SessionRunnerTests`: `onPermissionMissing` runs once when `canPostEvents` is false and not at all when it is true.

Add to `LocalizationTests`: `("notice.permissionGranted", "Keypad artık diğer uygulamalara yazabilir")`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit --filter "PermissionRecoveryTests|SessionRunnerTests|LocalizationTests"`
Expected: FAIL to compile on `PermissionRecovery`.

- [ ] **Step 3: Implement `PermissionRecovery`, the notice and the runner hook**

`SessionRunner.shortcutPressed()` reads `permission.canPostEvents` once, passes it into the `ShortcutContext`, and calls `onPermissionMissing` when it is false.

Add `notice.permissionGranted` to the catalog (English "Keypad can now type into other apps", Turkish "Keypad artık diğer uygulamalara yazabilir"), and the matching case in `NoticeView`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit`
Expected: PASS.

- [ ] **Step 5: Implement the adapters and wiring**

`TimerPermissionWatcher` uses a repeating 1-second `Timer`. `PostEventPermission.canPostEvents` becomes `AXIsProcessTrusted()`. `requestPostEventAccess()` keeps `CGRequestPostEventAccess()`.

In `AppDelegate`, create `PermissionRecovery` with the existing `permission` and `notices`. In `applicationDidFinishLaunching`, keep the existing request, then call `recovery.watchIfMissing()`, and set `runner.onPermissionMissing` to the same call.

- [ ] **Step 6: Update the docs**

- `README.md`: delete the "Then quit Keypad…" bullet under "First launch", and say Keypad starts working as soon as the switch is on.
- `docs/rfcs/0000-vision-and-architecture.md` §8.6: replace the polling of `CGPreflightPostEventAccess()` with `AXIsProcessTrusted()`, and point the first-run steps at RFC-0013.

- [ ] **Step 7: Verify on a signed build**

Install a signed build in `/Applications`: System Settings can't list an app in a temp folder. Turn the switch on: the notice appears within about a second, and the next session has no warning and types. Turn it off: the next session shows the warning. Turn it on again: the notice appears again.

- [ ] **Step 8: Commit, squash and merge**

`feat(permission): recover from a grant without a relaunch`

### Task 5: Pointer router

**Files:**
- Create: `Sources/KeypadCore/Input/PointerRouter.swift`
- Modify: `Sources/KeypadCore/Session/SessionEffect.swift`
- Test: create `Tests/KeypadCoreTests/PointerRouterTests.swift`

**Interfaces:**
- Produces:

```swift
public enum PointerMode: Equatable, Sendable { case keypad, pointer }
public enum MousePassThrough: Equatable, Sendable { case on, offAfterGrace, offNow }

// New SessionEffect cases
case pointer(PointerMode)
case mousePassThrough(MousePassThrough)

struct PointerRouter: Sendable {
    private(set) var mode: PointerMode
    init(area: ActiveArea, wakeDistance: Double = 0.04)
    mutating func handle(_ sample: TouchSample) -> [SessionEffect]
    /// Back to keypad mode; returns the effects only if it was in pointer mode.
    mutating func reset() -> [SessionEffect]
}
```

- [ ] **Step 1: Write the failing tests**

Use `ActiveArea(x: 0, y: 0, width: 0.5, height: 1)`, so `x` above `0.5` is outside. A small `sample(_ id:, _ phase:, x:)` helper keeps these short.

| Test | Samples | Expected |
|---|---|---|
| `stationaryTapOutsideDoesNothing` | began 0.8, ended 0.8 | `[]`, mode `.keypad` |
| `travelBelowTheLimitStaysAsleep` | began 0.8, moved 0.83 | `[]` |
| `travelOutsideWakesThePointer` | began 0.8, moved 0.85 | `[.pointer(.pointer), .mousePassThrough(.on)]` |
| `restingFingerOutsideStaysAsleepWhileTapping` | began 0.2 (id 1), began 0.8 (id 2), moved 0.9 (id 2) | `[]` |
| `aFingerSlidingOutOfTheAreaStaysAKeypadContact` | began 0.4, moved 0.9 | `[]` |
| `aFingerSlidingIntoTheAreaKeepsMovingThePointer` | wake, moved 0.3 | `[]`, mode `.pointer` |
| `lastLiftStartsTheGrace` | two outside fingers in pointer mode, both end | `[]`, then `[.mousePassThrough(.offAfterGrace)]` |
| `aCancelledContactCountsAsLifted` | wake, cancelled | `[.mousePassThrough(.offAfterGrace)]` |
| `landingOutsideInPointerModePassesMouseInput` | wake, ended, began 0.8 | last output `[.mousePassThrough(.on)]` |
| `landingInTheAreaEndsPassThroughAtOnce` | wake, ended, began 0.2 | `[.mousePassThrough(.offNow), .pointer(.keypad)]` |
| `wholeSurfaceNeverWakes` | `.fullSurface`, began 0.99, moved 0.5 | `[]` |
| `resetFromPointerModeFreezes` | wake, `reset()` | `[.mousePassThrough(.offNow), .pointer(.keypad)]` |
| `resetFromKeypadModeDoesNothing` | `reset()` | `[]` |

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit --filter PointerRouterTests`
Expected: FAIL to compile on `PointerRouter`.

- [ ] **Step 3: Implement `PointerRouter`**

Keep one contact per `TouchSample.id`, holding where it landed, whether it is inside (`area.map(point) != nil`), and whether it has travelled. A contact keeps its side for life. Use `hypot` from its start, as `TapRecognizer` does. Ignore samples for a contact it never saw begin: `reset()` can run with a finger still down.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit --filter PointerRouterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(session): add the pointer router`

### Task 6: Pointer mode in the session

**Files:**
- Modify: `Sources/KeypadCore/Session/SessionEngine.swift`, `SessionEvent.swift`, `SessionEffect.swift`, `SessionRunner.swift`, `SystemServices.swift`
- Test: `Tests/KeypadCoreTests/SessionEngineTests.swift`, `SessionRunnerTests.swift`, `Fakes.swift`

The app target doesn't build between this task and Task 7, because `HUDCaptureSurface` gains new requirements there. `swift test` is the check here.

**Interfaces:**
- Consumes: `PointerRouter`, `PointerMode`, `MousePassThrough`
- Produces:
  - `SessionEvent.clickReachedAnotherApp`
  - `SessionEffect.releaseFocus(to: AppIdentity)`
  - `HUDState.showsPointerHint: Bool`, a new init parameter defaulting to `false`
  - `CaptureSurface.setPointer(_ mode: PointerMode)`
  - `CaptureSurface.setMousePassThrough(_ state: MousePassThrough)`
  - `CaptureSurface.onClickThrough: (@MainActor () -> Void)?`
  - `FocusController.releaseFocus(to target: AppIdentity)`
  - `SessionRunner.clickReachedAnotherApp()`

- [ ] **Step 1: Write the failing tests**

In `SessionEngineTests`, use a configuration with the left half as the active area and a `wakePointer(&engine)` helper that sends a contact outside with travel:

```swift
@Test mutating func wakingShowsThePointerHint() { ... }           // last render: showsPointerHint == true
@Test mutating func tappingTheAreaEntersItsDigit() { ... }        // from pointer mode: buffer "7", hint false
@Test mutating func clickInPointerModeClosesAndDiscardsTheNumber() {
    // open, tap a digit, wake
    let effects = engine.handle(.clickReachedAnotherApp)
    #expect(effects == [.hideCapture(returnFocusTo: nil), .releaseFocus(to: chrome)])
    #expect(engine.state == .idle)
}
@Test mutating func clickInKeypadModeDoesNothing() { ... }        // effects == []
@Test mutating func commitFromPointerModeFreezesFirst() { ... }   // .pointer(.keypad) comes before .handOff
@Test mutating func noPointerRulesWhileThePermissionIsMissing() { ... } // travel outside: no .pointer effect
```

In `SessionRunnerTests`, extend `FakeSurface` to log `setPointer` and `setMousePassThrough`, add `releasedTo` to `FakeFocus`, and give `SessionHarness.init` an `activeArea: ActiveArea = .fullSurface` parameter. Add:
- `pointerEffectsReachTheSurface`.
- `clickReleasesFocusToTheTarget`.
- `everyExitLeavesTheNextSessionInKeypadMode`, run over `ExitPath.allCases`: wake, run the exit, reopen, then expect no `pointer` entry after the last `show`, and that a stationary tap outside changes nothing.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeypadKit --filter "SessionEngineTests|SessionRunnerTests"`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the engine and runner**

- `SessionEngine` holds a `PointerRouter`, recreated in `open` from `configuration.activeArea`.
- `handleTouch` runs the router first and puts its effects before the tap effects. Skip the router while `canPostEvents` is false.
- `hud(...)` sets `showsPointerHint: router.mode == .pointer`. Whenever the mode changes, add a `.render`.
- `beginHandOff` calls `router.reset()`, and the commit paths put those effects before `.handOff`.
- Add `case (.capturing, .clickReachedAnotherApp)`: in pointer mode it returns `close(returnFocusTo: nil) + [.releaseFocus(to: target)]`, otherwise `[]`.
- `SessionRunner` performs the three new effects and offers `clickReachedAnotherApp()`. Its init sets `surface.onClickThrough` the way it sets `focus.onInterruption`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit`
Expected: PASS.

- [ ] **Step 5: Commit**

`feat(session): add pointer mode and close on a click`

### Task 7: Pass-through adapters, hint and docs

**Files:**
- Modify: `Sources/KeypadSystem/Capture/CapturePanelController.swift`
- Modify: `Sources/KeypadSystem/Focus/WorkspaceFocusController.swift`
- Modify: `Sources/KeypadUI/HUD/KeypadHUDView.swift`, `Sources/KeypadUI/Resources/Localizable.xcstrings`
- Modify: `Keypad/HUDCaptureSurface.swift`
- Modify: `README.md`, `docs/glossary.md`, `docs/rfcs/0000-vision-and-architecture.md`
- Test: `Tests/KeypadUITests/LocalizationTests.swift`

**Interfaces:**
- Consumes: the `CaptureSurface` and `FocusController` additions from Task 6
- Produces:
  - `CapturePanelController.setPointer(_:)`
  - `CapturePanelController.setMousePassThrough(_:)`
  - `CapturePanelController.onClickThrough: (@MainActor () -> Void)?`
  - `WorkspaceFocusController.releaseFocus(to:)`

- [ ] **Step 1: Write the failing test**

Add to `LocalizationTests`: `("hud.pointerHint", "Tıklamak Keypad'i kapatır · Devam etmek için tuşlara dokunun")`.

- [ ] **Step 2: Run it to verify it fails**

Run: `swift test --package-path Packages/KeypadKit --filter LocalizationTests`
Expected: FAIL.

- [ ] **Step 3: Add the hint**

Add `hud.pointerHint` to the catalog (English "Clicking closes Keypad · Tap the keypad to continue"). `Footer` shows it in place of `hud.hint` while `showsPointerHint` is true.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeypadKit`
Expected: PASS.

- [ ] **Step 5: Implement the panel**

In `CapturePanelController`:
- `setPointer(_:)` calls `CGAssociateMouseAndMouseCursorPosition` with `1` for `.pointer` and `0` for `.keypad`. In pointer mode it also runs a global `NSEvent` monitor for `.leftMouseDown`, `.rightMouseDown` and `.otherMouseDown`, which calls `onClickThrough`. The monitor stops in keypad mode and in `hide()`.
- `setMousePassThrough(.on)` cancels the grace period and sets `panel.ignoresMouseEvents = true`.
- `.offNow` cancels the grace period and clears it at once.
- `.offAfterGrace` clears it after a `passThroughGrace` of 150 ms, then moves the panel to `NSScreen.underPointer` if the pointer is on another display.
- `hide()` also cancels the grace period and clears `ignoresMouseEvents`.

`HUDCaptureSurface` forwards the two setters and `onClickThrough`.

- [ ] **Step 6: Implement `releaseFocus(to:)`**

After the existing `reclaimCheck` delay, if `NSApplication.shared.isActive` is still true and `watchedTarget` is `nil`, call `returnFocus(to:)`. The `watchedTarget` check stops a stale release from acting on a session that has just opened.

- [ ] **Step 7: Update the docs**

Apply the rest of the RFC-0005 amendments:
- `docs/rfcs/0000-vision-and-architecture.md`: §5, §8.2 and §8.5.
- `docs/glossary.md`: update *Active area*, *Capture panel* and *Session* (a click in pointer mode also ends one); add *Keypad mode* and *Pointer mode*.
- `README.md`: update "Your part of the trackpad" and the FAQ answers "Does it change how my trackpad works?" and "What happens if I open Spotlight or Mission Control?".

- [ ] **Step 8: Verify on a signed build**

Set the active area to one half of the trackpad, with tap to click on. Check every row of the rules table in RFC-0005 §2, then that a click closes the session and the clicked app has focus. Check that the default whole-surface area behaves exactly as it did in `v0.1.1`.

- [ ] **Step 9: Commit, squash and merge**

`feat(session): let the trackpad work outside the active area`

### Task 8: QA and release

The PM runs this task on a real trackpad. Publishing needs the PM's explicit OK.

**Files:**
- Modify: `Keypad.xcodeproj/project.pbxproj` (`MARKETING_VERSION`, both configurations)
- Modify: `docs/rfcs/0005-permission-recovery-and-trackpad-pass-through.md`, `docs/rfcs/README.md`

- [ ] **Step 1: Run the QA**

Run the manual list in RFC-0005 "Testing", plus the rounds deferred in RFC-0002 and RFC-0003. For RFC-0002, run "a late keystroke is discarded" first. If a result changes behaviour, fix it on its own branch before continuing.

- [ ] **Step 2: Bump the version**

On `chore/release-0.2.0`, set `MARKETING_VERSION = 0.2.0` in both configurations. Commit `chore(release): prepare v0.2.0`, then merge into `develop`.

- [ ] **Step 3: Release**

Merge `develop` into `main` with `--no-ff` and tag `v0.2.0`. With the PM's OK, push `main` and the tag, then run `scripts/release.sh 0.2.0`.

- [ ] **Step 4: Record the results**

Add "QA results" and "Release results" to RFC-0005, set its status to Implemented here and in `docs/rfcs/README.md`, and commit on a `docs/…` branch.
