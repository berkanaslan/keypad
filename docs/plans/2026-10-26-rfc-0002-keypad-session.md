# RFC-0002 Keypad Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From any app, ⌃⌥K opens a keypad session; trackpad taps build a number in a Liquid Glass HUD; Return/Tab/arrows type it into the target app and keep the session open.

**Architecture:** A pure reducer (`SessionEngine`) and an effect interpreter (`SessionRunner`) in `KeypadCore` hold every rule and talk to the system only through `@MainActor` protocols. `KeypadSystem` implements those protocols with AppKit/Carbon/CoreGraphics; `KeypadUI` renders the HUD and the notice; the app target is the composition root that wires them together.

**Tech Stack:** Swift 6 (strict concurrency), SwiftPM tools 6.2, Swift Testing, SwiftUI (`glassEffect`, `GlassEffectContainer`), AppKit (`NSPanel`, `NSTouch`), Carbon (`RegisterEventHotKey`, `IsSecureEventInputEnabled`, `UCKeyTranslate`), CoreGraphics (`CGEvent`), `os.Logger`.

**Spec:** `docs/rfcs/0002-keypad-session.md` (foundation: `docs/rfcs/0000-vision-and-architecture.md` §7 F1–F11)

## Global Constraints

- Branch `feature/keypad-session` (from `develop`); merge into `develop` with `--no-ff`; never push without the PM's OK. Commits: Conventional Commits, author `git config user.email` must be the repo-local identity; end messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `KeypadCore` imports Foundation and `os` only — never AppKit, Carbon or SwiftUI. Dependencies point to Core. `KeypadSystem` and `KeypadUI` do not import each other.
- Swift 6 language mode, warnings are errors. Every system-facing protocol and adapter is `@MainActor`; Core value types are `Sendable`. No deprecated activation API (e.g. `activate(ignoringOtherApps:)`).
- Values pinned by the RFC: tap ≤ **0.4 s** and movement < **0.04**; hand-off settle **60 ms**, hand-off timeout **1.5 s**, reclaim check **150 ms**; key highlight **0.18 s**; capture dim **10 %**; display scale-down floor **60 %**; notice shown **2 s**; shortcut **⌃⌥K**; haptic `.generic` on touch-down; sound **"Tink"** on accepted tap.
- Logging: `Logger(subsystem: "io.berkan.keypad", category:)` with categories `session`, `focus`, `input`. Never log digits, buffer contents or key codes.
- Every new user-facing string goes into `Packages/KeypadKit/Sources/KeypadUI/Resources/Localizable.xcstrings` with `en` and `tr` values in the same commit. Exact copy:
  - `hud.hint` — en "Return, Tab or arrows to type · Esc to close" — tr "Yazmak için Return, Tab veya oklar · Kapatmak için Esc"
  - `hud.permissionMissing` — en "Keypad needs Accessibility access to type" — tr "Keypad'in yazabilmesi için Erişilebilirlik izni gerekiyor"
  - `hud.backspace.accessibilityLabel` — en "Delete" — tr "Sil"
  - `hud.target.accessibilityLabel` — en "Typing into %@" — tr "%@ uygulamasına yazılıyor"
  - `notice.secureInput` — en "Keypad can't type while secure input is on, for example in a password field" — tr "Güvenli giriş açıkken Keypad yazamaz, örneğin bir şifre alanında"
- No personal or affiliation data in code, docs or commits (AGENTS.md §4).
- Commands (from AGENTS.md §10): lint `swift format lint --recursive --strict Packages Keypad`; tests `swift test --package-path Packages/KeypadKit`; signed build per AGENTS.md §10 followed by the team check.

## Review Focus

1. **Pointer left frozen.** Every way out of a session (Esc, shortcut, non-sticky commit, interruption, hand-off timeout, reclaim failure, app termination) must hide the capture panel, which restores the pointer — `everyExitPathHidesTheSurface` in Task 5; termination in Task 10 Step 2.
2. **Typing into the wrong app.** If the hand-off fails or times out, nothing is typed — `failedHandOffTypesNothing` in Task 5.
3. **Turkish keyboard decimal.** On a Turkish layout the HUD shows "," and the main-keyboard comma counts as the decimal key, while "." does not — `mainKeyboardKeyMatchingSeparatorIsDecimal` / `otherPunctuationIsOther` in Task 6.
4. **Rapid double commit.** A second Tab during committing must not type twice — `keysDuringCommitAreIgnored` in Task 4.
5. **Two fingers and a resting palm.** Overlapping taps both count; a resting touch never types — `overlappingTouchesTapIndependently` / `restingTouchNeverTaps` in Task 2.

---

### Task 1: Geometry and layout

**Files:**
- Delete: `Packages/KeypadKit/Sources/KeypadCore/CoreModule.swift`, `Packages/KeypadKit/Tests/KeypadCoreTests/CoreModuleTests.swift`
- Create: `Packages/KeypadKit/Sources/KeypadCore/Geometry/TrackpadPoint.swift`, `.../Geometry/ActiveArea.swift`, `.../Layout/KeyAction.swift`, `.../Layout/Layout.swift`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/ActiveAreaTests.swift`, `.../LayoutTests.swift`

**Interfaces:**
- Produces: `public struct TrackpadPoint: Equatable, Sendable { public var x: Double; public var y: Double; public init(x: Double, y: Double) }` — origin bottom-left, `0...1`.
- Produces: `public struct ActiveArea: Equatable, Sendable { public init(x: Double, y: Double, width: Double, height: Double); public static let fullSurface: ActiveArea; public func map(_ point: TrackpadPoint) -> TrackpadPoint? }` — closed bounds; result relative to the area.
- Produces: `public enum KeyAction: Equatable, Sendable { case digit(Int), decimalSeparator, backspace }`
- Produces: `public struct Layout: Equatable, Sendable { public struct Cell: Equatable, Sendable { public let action: KeyAction; public let row: Int; public let column: Int; public let rowSpan: Int; public let columnSpan: Int }; public let rows: Int; public let columns: Int; public let cells: [Cell]; public func cell(at point: TrackpadPoint) -> Cell?; public static let numpad: Layout }` — row 0 is the top.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ActiveAreaTests {
    @Test func fullSurfaceMapsPointsUnchanged() {
        #expect(ActiveArea.fullSurface.map(TrackpadPoint(x: 0.25, y: 0.75)) == TrackpadPoint(x: 0.25, y: 0.75))
    }
    @Test func pointsOutsideTheAreaAreIgnored() {
        let rightHalf = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(rightHalf.map(TrackpadPoint(x: 0.3, y: 0.5)) == nil)
    }
    @Test func pointsInsideAreRelativeToTheArea() {
        let rightHalf = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(rightHalf.map(TrackpadPoint(x: 0.75, y: 0.5)) == TrackpadPoint(x: 0.5, y: 0.5))
    }
    @Test func edgesBelongToTheArea() {
        #expect(ActiveArea.fullSurface.map(TrackpadPoint(x: 1, y: 0)) == TrackpadPoint(x: 1, y: 0))
    }
}

@Suite struct LayoutTests {
    @Test func numpadIsThreeByFour() {
        #expect(Layout.numpad.rows == 4 && Layout.numpad.columns == 3 && Layout.numpad.cells.count == 12)
    }
    @Test func topLeftIsSeven() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0.1, y: 0.95))?.action == .digit(7))
    }
    @Test func bottomRowIsZeroSeparatorBackspace() {
        let actions = [0.1, 0.5, 0.9].map { Layout.numpad.cell(at: TrackpadPoint(x: $0, y: 0.05))?.action }
        #expect(actions == [.digit(0), .decimalSeparator, .backspace])
    }
    @Test func centreIsFive() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0.5, y: 0.6))?.action == .digit(5))
    }
    @Test func outerEdgesClampIntoTheGrid() {
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 1, y: 1))?.action == .digit(9))
        #expect(Layout.numpad.cell(at: TrackpadPoint(x: 0, y: 0))?.action == .digit(0))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --package-path Packages/KeypadKit --filter "ActiveAreaTests|LayoutTests"`
Expected: FAIL — `cannot find 'ActiveArea' in scope`.

- [ ] **Step 3: Implement the four types**

`Layout.cell(at:)`: `row = min(rows - 1, Int((1 - y) * Double(rows)))`, `column = min(columns - 1, Int(x * Double(columns)))`, then the first cell whose row/column span covers that slot. `numpad` cells have span 1.

- [ ] **Step 4: Run to verify pass**

Run: same as Step 2. Expected: 9 tests passed.

- [ ] **Step 5: Commit**

`git commit -m "feat(core): add trackpad geometry, active area and numpad layout"`

---

### Task 2: Tap recognition

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadCore/Input/TouchSample.swift`, `.../Input/TapRecognizer.swift`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/TapRecognizerTests.swift`

**Interfaces:**
- Consumes: `TrackpadPoint` (Task 1).
- Produces: `public struct TouchSample: Equatable, Sendable { public enum Phase: Equatable, Sendable { case began, moved, ended, cancelled }; public let id: Int; public let phase: Phase; public let point: TrackpadPoint; public let time: TimeInterval; public init(id:phase:point:time:) }`
- Produces: `public enum TapEvent: Equatable, Sendable { case touchDown(TrackpadPoint), tap(TrackpadPoint) }` and `public struct TapRecognizer: Sendable { public init(maxDuration: TimeInterval = 0.4, maxMovement: Double = 0.04); public mutating func handle(_ sample: TouchSample) -> TapEvent? }` — `.tap` carries the touch's **starting** point.

- [ ] **Step 1: Write the failing tests**

Helper: `func sample(_ id: Int, _ phase: TouchSample.Phase, _ x: Double, _ y: Double, _ t: TimeInterval) -> TouchSample`.

```swift
@Suite struct TapRecognizerTests {
    @Test func beganEmitsTouchDown() {
        var r = TapRecognizer()
        #expect(r.handle(sample(1, .began, 0.2, 0.8, 0)) == .touchDown(TrackpadPoint(x: 0.2, y: 0.8)))
    }
    @Test func quickStillTouchIsATapAtItsStartPoint() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        #expect(r.handle(sample(1, .ended, 0.21, 0.8, 0.15)) == .tap(TrackpadPoint(x: 0.2, y: 0.8)))
    }
    @Test func restingTouchNeverTaps() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.41)) == nil)
    }
    @Test func movedTouchIsNotATap() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(1, .moved, 0.25, 0.8, 0.1))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.2)) == nil)
    }
    @Test func cancelledTouchIsNotATap() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(1, .cancelled, 0.2, 0.8, 0.1))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.15)) == nil)
    }
    @Test func overlappingTouchesTapIndependently() {
        var r = TapRecognizer()
        _ = r.handle(sample(1, .began, 0.2, 0.8, 0))
        _ = r.handle(sample(2, .began, 0.8, 0.2, 0.05))
        #expect(r.handle(sample(1, .ended, 0.2, 0.8, 0.1)) == .tap(TrackpadPoint(x: 0.2, y: 0.8)))
        #expect(r.handle(sample(2, .ended, 0.8, 0.2, 0.2)) == .tap(TrackpadPoint(x: 0.8, y: 0.2)))
    }
    @Test func endWithoutBeginIsIgnored() {
        var r = TapRecognizer()
        #expect(r.handle(sample(9, .ended, 0.5, 0.5, 1)) == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --package-path Packages/KeypadKit --filter TapRecognizerTests` → FAIL, `TapRecognizer` not found.
- [ ] **Step 3: Implement** — track `[Int: (start: TrackpadPoint, time: TimeInterval, moved: Bool)]`; `moved` becomes true when the distance from the start reaches `maxMovement`; `.ended` returns `.tap` only when not moved and `time - start.time <= maxDuration`, and removes the entry.
- [ ] **Step 4: Run to verify pass** — 7 tests passed.
- [ ] **Step 5: Commit** — `feat(core): recognize taps from trackpad touch samples`

---

### Task 3: Entry buffer and keystrokes

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadCore/Entry/Keystroke.swift`, `.../Entry/EntryBuffer.swift`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/EntryBufferTests.swift`

**Interfaces:**
- Consumes: `KeyAction` (Task 1).
- Produces: `public enum ArrowDirection: Equatable, Sendable { case left, right, up, down }`; `public enum CommitKey: Equatable, Sendable { case returnKey, shiftReturn, keypadEnter, tab, shiftTab, arrow(ArrowDirection) }`; `public enum Keystroke: Equatable, Sendable { case keypadDigit(Int), keypadDecimal, commit(CommitKey) }`
- Produces: `public struct EntryBuffer: Equatable, Sendable { public init(); public private(set) var actions: [KeyAction]; public var isEmpty: Bool; public mutating func apply(_ action: KeyAction); public func display(decimalSeparator: String) -> String; public var keystrokes: [Keystroke] }` — `actions` holds only `.digit` and `.decimalSeparator`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct EntryBufferTests {
    @Test func digitsAndSeparatorBuildTheDisplay() {
        var b = EntryBuffer()
        [.digit(1), .digit(2), .decimalSeparator, .digit(5)].forEach { b.apply($0) }
        #expect(b.display(decimalSeparator: ",") == "12,5")
        #expect(b.display(decimalSeparator: ".") == "12.5")
    }
    @Test func noValidationLikeAHardwareNumpad() {
        var b = EntryBuffer()
        [.digit(0), .digit(0), .decimalSeparator, .decimalSeparator, .digit(7)].forEach { b.apply($0) }
        #expect(b.display(decimalSeparator: ".") == "00..7")
    }
    @Test func backspaceRemovesTheLastCharacter() {
        var b = EntryBuffer()
        [.digit(4), .digit(2), .backspace].forEach { b.apply($0) }
        #expect(b.display(decimalSeparator: ".") == "4")
    }
    @Test func backspaceOnEmptyDoesNothing() {
        var b = EntryBuffer()
        b.apply(.backspace)
        #expect(b.isEmpty)
    }
    @Test func keystrokesMirrorTheEntry() {
        var b = EntryBuffer()
        [.digit(3), .decimalSeparator, .digit(0)].forEach { b.apply($0) }
        #expect(b.keystrokes == [.keypadDigit(3), .keypadDecimal, .keypadDigit(0)])
    }
}
```

- [ ] **Step 2: Run to verify failure** — `--filter EntryBufferTests` → FAIL.
- [ ] **Step 3: Implement both files.**
- [ ] **Step 4: Run to verify pass** — 5 tests passed.
- [ ] **Step 5: Commit** — `feat(core): add entry buffer and keystroke model`

---

### Task 4: Session engine

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadCore/Session/AppIdentity.swift`, `.../Session/KeyInput.swift`, `.../Session/SessionConfiguration.swift`, `.../Session/SessionEvent.swift`, `.../Session/SessionEffect.swift`, `.../Session/SessionEngine.swift`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/SessionEngineTests.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `public struct AppIdentity: Equatable, Sendable { public let processID: Int32; public let bundleIdentifier: String?; public let name: String; public init(processID:bundleIdentifier:name:) }`
  - `public enum KeyInput: Equatable, Sendable { case digit(Int), decimalSeparator, deleteBackward, commit(CommitKey), escape, other }`
  - `public enum SecureInputPolicy: Equatable, Sendable { case open, notify }`; `public struct SessionConfiguration: Equatable, Sendable { public var layout: Layout = .numpad; public var activeArea: ActiveArea = .fullSurface; public var isSticky = true; public var secureInputPolicy: SecureInputPolicy = .notify; public init() }`
  - `public struct ShortcutContext: Equatable, Sendable { public let frontmost: AppIdentity?; public let isKeypadFrontmost: Bool; public let isSecureInputOn: Bool; public let canPostEvents: Bool; public init(...) }`
  - `public enum SessionEvent: Equatable, Sendable { case shortcutPressed(ShortcutContext), touch(TouchSample), key(KeyInput), handOffFinished(succeeded: Bool), reclaimFinished(succeeded: Bool), interrupted }`
  - `public enum Notice: Equatable, Sendable { case secureInput }`; `public enum FeedbackEvent: Equatable, Sendable { case touchDown, keyAccepted }`
  - `public struct HUDState: Equatable, Sendable { public let target: AppIdentity; public let layout: Layout; public let buffer: EntryBuffer; public let highlightedCell: Layout.Cell?; public let showsPermissionWarning: Bool }`
  - `public enum SessionEffect: Equatable, Sendable { case showCapture(HUDState), render(HUDState), hideCapture(returnFocusTo: AppIdentity?), showNotice(Notice), feedback(FeedbackEvent), handOff(to: AppIdentity), type([Keystroke]), reclaimFocus }`
  - `public enum SessionState: Equatable, Sendable { case idle, capturing, committing, reclaiming }`
  - `public struct SessionEngine: Sendable { public init(configuration: SessionConfiguration); public private(set) var state: SessionState; public mutating func handle(_ event: SessionEvent) -> [SessionEffect] }`

Rules — exactly the RFC's state table, with these resolutions: a commit stores `buffer.keystrokes + [.commit(key)]` as pending, clears the buffer and emits `[.render(…), .handOff(to: target)]`; `.handOffFinished(true)` emits `[.type(pending)]` followed by `.reclaimFocus` (sticky, → reclaiming) or `.hideCapture(returnFocusTo: nil)` (not sticky or closing by shortcut, → idle); `.handOffFinished(false)` emits `[.hideCapture(returnFocusTo: nil)]` and drops pending; `.reclaimFinished(true)` → capturing with `[.render]`; `(false)` → idle with `[.hideCapture(returnFocusTo: nil)]`; Esc and an empty-buffer shortcut emit `[.hideCapture(returnFocusTo: target)]`; `.interrupted` in any non-idle state emits `[.hideCapture(returnFocusTo: nil)]`; touches and keys while committing or reclaiming emit nothing.

- [ ] **Step 1: Write the failing tests** — fixtures: `let chrome = AppIdentity(processID: 42, bundleIdentifier: "com.google.Chrome", name: "Chrome")`; `func open(_ engine: inout SessionEngine, canPost: Bool = true)` sends `.shortcutPressed(ShortcutContext(frontmost: chrome, isKeypadFrontmost: false, isSecureInputOn: false, canPostEvents: canPost))`; `func tap(_ engine: inout SessionEngine, x: Double, y: Double)` sends began + ended 0.1 s apart.

| Test | Arrange → act | Assert |
|---|---|---|
| `shortcutOpensOverTheFrontmostApp` | idle → open | effects first is `.showCapture` whose `target == chrome`; `state == .capturing` |
| `shortcutIsIgnoredWhenKeypadIsFrontmost` | context `isKeypadFrontmost: true` | effects `[]`; `.idle` |
| `shortcutIsIgnoredWithoutFrontmostApp` | context `frontmost: nil` | `[]`; `.idle` |
| `secureInputShowsNoticeWhenPolicyIsNotify` | `isSecureInputOn: true` | `[.showNotice(.secureInput)]`; `.idle` |
| `secureInputOpensWhenPolicyIsOpen` | configuration `.open`, `isSecureInputOn: true` | `.capturing` |
| `touchDownOnACellPlaysFeedbackAndHighlights` | open → began at (0.1, 0.95) | contains `.feedback(.touchDown)`; last render's `highlightedCell?.action == .digit(7)` |
| `tapAppliesTheCellAction` | open → tap (0.1, 0.95) | contains `.feedback(.keyAccepted)`; last render `buffer.display(decimalSeparator: ".") == "7"` |
| `touchOutsideTheActiveAreaDoesNothing` | `activeArea = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)` → began at (0.2, 0.5) | `[]` |
| `keyboardDigitsEditTheBuffer` | open → `.key(.digit(4))`, `.key(.decimalSeparator)`, `.key(.deleteBackward)` | last render display `"4"` |
| `otherKeysAreSwallowedSilently` | open → `.key(.other)` | `[]`; `.capturing` |
| `commitHandsOffWithPendingKeystrokes` | open → tap 7 → `.key(.commit(.tab))` | contains `.handOff(to: chrome)`; `.committing` |
| `handOffTypesThenReclaimsWhenSticky` | … → `.handOffFinished(succeeded: true)` | `== [.type([.keypadDigit(7), .commit(.tab)]), .reclaimFocus]`; `.reclaiming` |
| `handOffTypesThenClosesWhenNotSticky` | `isSticky = false` | `== [.type([.keypadDigit(7), .commit(.tab)]), .hideCapture(returnFocusTo: nil)]`; `.idle` |
| `emptyCommitStillSendsTheKey` | open → `.key(.commit(.returnKey))` → `.handOffFinished(true)` | first effect `== .type([.commit(.returnKey)])` |
| `failedHandOffClosesWithoutTyping` | commit → `.handOffFinished(succeeded: false)` | `== [.hideCapture(returnFocusTo: nil)]`; `.idle` |
| `reclaimReturnsToCapturingWithAnEmptyBuffer` | sticky commit → reclaim true | `.capturing`; render buffer `isEmpty` |
| `reclaimFailureCloses` | → `.reclaimFinished(succeeded: false)` | `== [.hideCapture(returnFocusTo: nil)]`; `.idle` |
| `keysDuringCommitAreIgnored` | commit → (committing) `.key(.commit(.tab))` | `[]`; still `.committing` |
| `escapeClosesAndReturnsFocus` | open → tap → `.key(.escape)` | `== [.hideCapture(returnFocusTo: chrome)]`; `.idle` |
| `shortcutWithPendingNumberTypesAndCloses` | open → tap 7 → shortcut → `.handOffFinished(true)` | second batch `== [.type([.keypadDigit(7)]), .hideCapture(returnFocusTo: nil)]` |
| `shortcutWithEmptyBufferCloses` | open → shortcut | `== [.hideCapture(returnFocusTo: chrome)]` |
| `interruptionDiscardsAndCloses` | open → tap → `.interrupted` | `== [.hideCapture(returnFocusTo: nil)]`; `.idle` |
| `missingPermissionBlocksCommitAndWarns` | `open(canPost: false)` → tap → commit | no `.handOff`; last render `showsPermissionWarning == true`; buffer still `"7"` |

- [ ] **Step 2: Run to verify failure** — `--filter SessionEngineTests` → FAIL.
- [ ] **Step 3: Implement the six files.** The engine owns a `TapRecognizer`, the configuration, `target`, `buffer`, `pending: [Keystroke]`, `closesAfterTyping: Bool` and `canPostEvents` (from the opening context).
- [ ] **Step 4: Run to verify pass** — 23 tests passed.
- [ ] **Step 5: Commit** — `feat(core): add the keypad session state machine`

---

### Task 5: System protocols and session runner

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadCore/Session/SystemServices.swift`, `.../Session/SessionRunner.swift`
- Test: `Packages/KeypadKit/Tests/KeypadCoreTests/SessionRunnerTests.swift`, `.../Fakes.swift`

**Interfaces:**
- Consumes: Task 4.
- Produces (all `@MainActor public protocol`, in `SystemServices.swift`):
  - `CaptureSurface: AnyObject { func show(_ hud: HUDState); func render(_ hud: HUDState); func hide(); func makeKey(); var isKey: Bool { get } }`
  - `FocusController: AnyObject { var frontmost: AppIdentity? { get }; var isKeypadFrontmost: Bool { get }; var onInterruption: (@MainActor () -> Void)? { get set }; func beginWatching(target: AppIdentity); func stopWatching(); func handOff(to target: AppIdentity, completion: @escaping @MainActor (Bool) -> Void); func reclaim(completion: @escaping @MainActor (Bool) -> Void); func returnFocus(to target: AppIdentity) }`
  - `KeystrokeSender { func send(_ keystrokes: [Keystroke]) }`; `FeedbackPlayer { func play(_ event: FeedbackEvent) }`; `NoticeSurface { func show(_ notice: Notice) }`; `PermissionChecker { var canPostEvents: Bool { get }; func requestPostEventAccess() }`; `SecureInputChecker { var isSecureInputOn: Bool { get } }`; `DecimalSeparatorProvider { var decimalSeparator: String { get } }`
- Produces: `@MainActor public final class SessionRunner { public init(configuration: SessionConfiguration, surface: CaptureSurface, focus: FocusController, keystrokes: KeystrokeSender, feedback: FeedbackPlayer, notices: NoticeSurface, permission: PermissionChecker, secureInput: SecureInputChecker); public var state: SessionState { get }; public func shortcutPressed(); public func receive(_ sample: TouchSample); @discardableResult public func receive(_ key: KeyInput) -> Bool }` — `receive(_ key:)` returns `true` (swallow) whenever the state is not `.idle`.

`shortcutPressed()` builds the `ShortcutContext` from `focus.frontmost`, `focus.isKeypadFrontmost`, `secureInput.isSecureInputOn` and `permission.canPostEvents`.

Interpretation, in effect order: `.showCapture` → `focus.beginWatching(target:)`, `surface.show`; `.render` → `surface.render`; `.hideCapture(r)` → `surface.hide()`, `focus.stopWatching()`, then `focus.returnFocus(to: r)` if non-nil; `.showNotice` → `notices.show`; `.feedback` → `feedback.play`; `.handOff(t)` → `focus.handOff(to: t) { engine.handle(.handOffFinished(succeeded: $0)) }`; `.type(k)` → `keystrokes.send(k)`; `.reclaimFocus` → `focus.reclaim { ok in engine.handle(.reclaimFinished(succeeded: ok && surface.isKey)) }` immediately followed by `surface.makeKey()`. `focus.onInterruption` is set in `init` to send `.interrupted`. Log every state change to category `session` as `"\(old) → \(new)"` only.

- [ ] **Step 1: Write the failing tests** — `Fakes.swift` defines recording fakes for every protocol (`FakeSurface` with `log: [String]` and settable `isKey`; `FakeFocus` whose `handOff`/`reclaim` store their completions for the test to call; `FakeKeystrokes` with `sent: [[Keystroke]]`; others record calls).

| Test | Assert |
|---|---|
| `shortcutOpensTheSurfaceOverTheFrontmostApp` | `surface.log == ["show"]`; `focus.watching == chrome` |
| `stickyCommitTypesThenReclaimsAndMakesKey` | after Tab + `focus.completeHandOff(true)`: `keystrokes.sent == [[.commit(.tab)]]`, `surface.log` ends with `"makeKey"`; after `focus.completeReclaim(true)`: `runner.state == .capturing` |
| `reclaimCountsAsFailedWhenThePanelIsNotKey` | `surface.isKey = false`, reclaim completes `true` → `runner.state == .idle`, `surface.log.last == "hide"` |
| `failedHandOffTypesNothing` | handOff completes `false` → `keystrokes.sent.isEmpty`, `runner.state == .idle` |
| `everyExitPathHidesTheSurface` | parameterized over Esc, shortcut, non-sticky commit, `focus.onInterruption?()`, failed hand-off, failed reclaim → each ends with `surface.log.last == "hide"` and `focus.watching == nil` |
| `escapeReturnsFocusToTheTarget` | `focus.returnedTo == chrome` |
| `keysAreSwallowedOnlyDuringASession` | idle: `receive(.digit(1)) == false`; capturing: `== true` |
| `noticeShownForSecureInput` | `secureInput.isSecureInputOn = true` → `notices.shown == [.secureInput]`, `surface.log.isEmpty` |

- [ ] **Step 2: Run to verify failure** — `--filter SessionRunnerTests` → FAIL.
- [ ] **Step 3: Implement both files.**
- [ ] **Step 4: Run to verify pass** — 13 test cases passed (8 tests, one parameterized over 6 paths); then the whole package: `swift test --package-path Packages/KeypadKit` all green.
- [ ] **Step 5: Commit** — `feat(core): run session effects against system service protocols`

---

### Task 6: Keyboard input and keystroke output

**Files:**
- Delete: `Packages/KeypadKit/Sources/KeypadSystem/SystemModule.swift`, `Packages/KeypadKit/Tests/KeypadSystemTests/SystemModuleTests.swift`
- Create: `Packages/KeypadKit/Sources/KeypadSystem/Keyboard/KeyboardClassifier.swift`, `.../Keyboard/KeyboardMonitor.swift`, `.../Keyboard/KeyboardLayoutDecimalSeparator.swift`, `.../Output/KeystrokeMapping.swift`, `.../Output/CGEventKeystrokeSender.swift`
- Test: `Packages/KeypadKit/Tests/KeypadSystemTests/KeyboardClassifierTests.swift`, `.../KeystrokeMappingTests.swift`

**Interfaces:**
- Consumes: `KeyInput`, `CommitKey`, `Keystroke`, `KeystrokeSender`, `DecimalSeparatorProvider` (Tasks 3–5).
- Produces: `public enum KeyboardClassifier { public static func classify(keyCode: UInt16, characters: String?, isShiftDown: Bool, decimalSeparator: String) -> KeyInput }` — digit when `characters` is a single `0`–`9`; decimal for `kVK_ANSI_KeypadDecimal` or when `characters == decimalSeparator`; `kVK_Delete` → `.deleteBackward`; `kVK_Return` → `.returnKey`/`.shiftReturn`; `kVK_ANSI_KeypadEnter` → `.keypadEnter`; `kVK_Tab` → `.tab`/`.shiftTab`; arrow key codes → `.arrow`; `kVK_Escape` → `.escape`; else `.other`.
- Produces: `public struct KeyEvent: Equatable, Sendable { public let code: CGKeyCode; public let flags: CGEventFlags }` and `public enum KeystrokeMapping { public static func keyEvent(for keystroke: Keystroke) -> KeyEvent }` — keypad digits `kVK_ANSI_Keypad0…9` and `kVK_ANSI_KeypadDecimal` with `.maskNumericPad`; Return `kVK_Return` `[]`; ⇧Return `.maskShift`; keypad Enter `kVK_ANSI_KeypadEnter` `.maskNumericPad`; Tab `kVK_Tab` `[]`; ⇧Tab `.maskShift`; arrows `[.maskNumericPad, .maskSecondaryFn]`.
- Produces: `@MainActor public final class CGEventKeystrokeSender: KeystrokeSender { public init() }` (private-state source, `.cghidEventTap`); `@MainActor public final class KeyboardMonitor { public init(decimalSeparator: DecimalSeparatorProvider); public func start(_ handler: @escaping @MainActor (KeyInput) -> Bool); public func stop() }` (local key-down monitor; extract `keyCode`, `characters`, Shift outside `MainActor.assumeIsolated`; return `nil` when the handler swallows); `@MainActor public final class KeyboardLayoutDecimalSeparator: DecimalSeparatorProvider { public init() }` (`TISCopyCurrentKeyboardLayoutInputSource` + `UCKeyTranslate` for `kVK_ANSI_KeypadDecimal`, falling back to `Locale.current.decimalSeparator ?? "."`; cache, refresh on `kTISNotifySelectedKeyboardInputSourceChanged`).

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct KeyboardClassifierTests {
    @Test func topRowAndKeypadDigitsAreDigits() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_7), characters: "7", isShiftDown: false, decimalSeparator: ",") == .digit(7))
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_Keypad3), characters: "3", isShiftDown: false, decimalSeparator: ",") == .digit(3))
    }
    @Test func shiftedDigitKeyIsOther() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_1), characters: "!", isShiftDown: true, decimalSeparator: ",") == .other)
    }
    @Test func keypadDecimalIsDecimal() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_KeypadDecimal), characters: ",", isShiftDown: false, decimalSeparator: ",") == .decimalSeparator)
    }
    @Test func mainKeyboardKeyMatchingSeparatorIsDecimal() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_Backslash), characters: ",", isShiftDown: false, decimalSeparator: ",") == .decimalSeparator)
    }
    @Test func otherPunctuationIsOther() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_ANSI_Slash), characters: ".", isShiftDown: false, decimalSeparator: ",") == .other)
    }
    @Test func commitKeysRespectShift() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_Return), characters: "\r", isShiftDown: true, decimalSeparator: ".") == .commit(.shiftReturn))
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_Tab), characters: "\t", isShiftDown: true, decimalSeparator: ".") == .commit(.shiftTab))
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_DownArrow), characters: nil, isShiftDown: false, decimalSeparator: ".") == .commit(.arrow(.down)))
    }
    @Test func escapeAndDelete() {
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_Escape), characters: "\u{1b}", isShiftDown: false, decimalSeparator: ".") == .escape)
        #expect(KeyboardClassifier.classify(keyCode: UInt16(kVK_Delete), characters: "\u{7f}", isShiftDown: false, decimalSeparator: ".") == .deleteBackward)
    }
}

@Suite struct KeystrokeMappingTests {
    @Test func keypadDigitsCarryTheNumericPadFlag() {
        #expect(KeystrokeMapping.keyEvent(for: .keypadDigit(8)) == KeyEvent(code: CGKeyCode(kVK_ANSI_Keypad8), flags: .maskNumericPad))
    }
    @Test func shiftTabCarriesShift() {
        #expect(KeystrokeMapping.keyEvent(for: .commit(.shiftTab)) == KeyEvent(code: CGKeyCode(kVK_Tab), flags: .maskShift))
    }
    @Test func arrowsCarryNumericPadAndFn() {
        #expect(KeystrokeMapping.keyEvent(for: .commit(.arrow(.left))) == KeyEvent(code: CGKeyCode(kVK_LeftArrow), flags: [.maskNumericPad, .maskSecondaryFn]))
    }
    @Test func plainReturnHasNoFlags() {
        #expect(KeystrokeMapping.keyEvent(for: .commit(.returnKey)) == KeyEvent(code: CGKeyCode(kVK_Return), flags: []))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `--filter "KeyboardClassifierTests|KeystrokeMappingTests"` → FAIL.
- [ ] **Step 3: Implement the five files.** `KeyEvent` needs an explicit `init(code:flags:)` for the tests.
- [ ] **Step 4: Run to verify pass** — 11 tests passed.
- [ ] **Step 5: Commit** — `feat(system): classify keyboard input and map keystrokes to key events`

---

### Task 7: Focus, permission, secure input, feedback and hotkey adapters

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadSystem/Focus/AppIdentity+RunningApplication.swift`, `.../Focus/WorkspaceFocusController.swift`, `.../Permissions/PostEventPermission.swift`, `.../Permissions/CarbonSecureInputChecker.swift`, `.../Feedback/SystemFeedbackPlayer.swift`, `.../Hotkey/CarbonHotkey.swift`

**Interfaces:**
- Consumes: protocols from Task 5.
- Produces: `extension AppIdentity { public init(_ app: NSRunningApplication) }` (`name` = `localizedName ?? bundleIdentifier ?? ""`).
- Produces: `@MainActor public final class WorkspaceFocusController: FocusController { public init(settleDelay: Duration = .milliseconds(60), handOffTimeout: Duration = .seconds(1.5), reclaimCheck: Duration = .milliseconds(150)) }` — hand-off and reclaim exactly as RFC-0000 F6/F7; while watching, report an interruption when another app (neither Keypad nor a target being handed off to) activates, when the target terminates, when the screen locks (`NSWorkspace.sessionDidResignActiveNotification`) or when screens change (`NSApplication.didChangeScreenParametersNotification`); log to category `focus`.
- Produces: `PostEventPermission: PermissionChecker`, `CarbonSecureInputChecker: SecureInputChecker` (each `@MainActor public final class` with `public init()`).
- Produces: `@MainActor public final class SystemFeedbackPlayer: FeedbackPlayer { public init(soundName: String = "Tink") }`.
- Produces: `@MainActor public final class CarbonHotkey { public init(keyCode: UInt32 = UInt32(kVK_ANSI_K), modifiers: UInt32 = UInt32(controlKey | optionKey)); public var onPress: (@MainActor () -> Void)?; @discardableResult public func register() -> Bool }` — the pattern verified for Swift 6: C callback → `Unmanaged` → `MainActor.assumeIsolated`; log a failed registration to category `input`.

- [ ] **Step 1: Write the six files.** These are thin system calls with no branching worth unit-testing; the session behaviour they serve is covered by Task 5, and they are exercised by the QA matrix (Task 11).
- [ ] **Step 2: Build** — `swift build --package-path Packages/KeypadKit` → `Build complete!`, no warnings.
- [ ] **Step 3: Run the whole package's tests** — all green.
- [ ] **Step 4: Commit** — `feat(system): add focus, permission, secure input, feedback and hotkey adapters`

---

### Task 8: Capture panel, touch view and notice panel

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadSystem/Capture/TouchCaptureView.swift`, `.../Capture/CapturePanel.swift`, `.../Capture/CapturePanelController.swift`, `.../Notice/NoticePanelController.swift`

**Interfaces:**
- Consumes: `TouchSample`, `TrackpadPoint`, `Notice`, `NoticeSurface` (Tasks 2, 4, 5).
- Produces: `final class TouchCaptureView: NSView` (internal) — `allowedTouchTypes = [.indirect]`, `wantsRestingTouches = true`; assigns stable `Int` IDs per `NSTouch.identity` (`isEqual`) and reports `TouchSample`s via `var onSample: ((TouchSample) -> Void)?`; swallows `mouseDown`, `rightMouseDown`, `otherMouseDown`, `scrollWheel`, `magnify`, `rotate`, `swipe`.
- Produces: `@MainActor public final class CapturePanelController { public init(content: NSView); public var onTouch: (@MainActor (TouchSample) -> Void)?; public func show(); public func hide(); public func makeKey(); public var isKey: Bool { get } }` — panel per the RFC table (borderless, `.nonactivatingPanel`, `canBecomeKey`, `.statusBar`, collection behaviour, 10 % dim from `NSColor.black.withAlphaComponent(0.1)`), placed on `NSScreen` containing `NSEvent.mouseLocation`; content centred with Auto Layout, touch view on top filling the panel; `show()` orders Keypad's other visible windows out and `hide()` puts them back with `orderBack(nil)`; `show()` calls `CGAssociateMouseAndMouseCursorPosition(0)`, `hide()` calls `CGAssociateMouseAndMouseCursorPosition(1)`; `hide()` is safe to call when hidden.
- Produces: `@MainActor public final class NoticePanelController: NoticeSurface { public init(duration: Duration = .seconds(2), content: @escaping @MainActor (Notice) -> NSView) }` — borderless non-activating panel, `ignoresMouseEvents = true`, never key, on the pointer's display, lower third, hides after `duration`.

- [ ] **Step 1: Write the four files.** AppKit-only, verified on the real trackpad in Task 11.
- [ ] **Step 2: Build** — `swift build --package-path Packages/KeypadKit` → no warnings.
- [ ] **Step 3: Commit** — `feat(system): add capture panel, touch capture and notice panel`

---

### Task 9: HUD and notice views

**Files:**
- Create: `Packages/KeypadKit/Sources/KeypadUI/HUD/KeypadHUDModel.swift`, `.../HUD/KeypadHUDView.swift`, `.../HUD/NumberDisplay.swift`, `.../Notice/NoticeView.swift`
- Modify: `Packages/KeypadKit/Sources/KeypadUI/Resources/Localizable.xcstrings` (the five keys in Global Constraints)
- Modify: `docs/glossary.md` (add **Notice**: "A short, non-interactive message Keypad shows instead of opening a session, e.g. when secure input is on.")
- Test: `Packages/KeypadKit/Tests/KeypadUITests/LocalizationTests.swift`

**Interfaces:**
- Consumes: `HUDState`, `Layout`, `Notice`, `AppIdentity` (Tasks 1, 4).
- Produces: `@MainActor @Observable public final class KeypadHUDModel { public init(); public private(set) var hud: HUDState?; public private(set) var highlightedCell: Layout.Cell?; public var decimalSeparator: String; public func apply(_ hud: HUDState) }` — `apply` sets `highlightedCell` from the state and clears it after 0.18 s (cancelling a pending clear).
- Produces: `public struct KeypadHUDView: View { public init(model: KeypadHUDModel) }` — target row (icon via `NSRunningApplication(processIdentifier:)?.icon`, name, accessibility label `hud.target.accessibilityLabel`), `NumberDisplay`, grid from `hud.layout` inside `GlassEffectContainer`, each cell `.glassEffect(highlighted ? .regular.tint(.accentColor) : .regular, in: .rect(cornerRadius: 16))`, backspace cell labelled `hud.backspace.accessibilityLabel`, decimal cell shows `decimalSeparator`; footer `hud.hint` or `hud.permissionMissing`. Highlight change animates (0.18 s) unless `accessibilityReduceMotion`.
- Produces: `struct NumberDisplay: View` — the non-truncating rule as `ViewThatFits(in: .horizontal) { full size, one line } { 60 % size, one line } { 60 % size, wrapping, fixedSize(horizontal: false, vertical: true) }` within the HUD's maximum width.
- Produces: `public struct NoticeView: View { public init(notice: Notice) }` — one line, `notice.secureInput`, in a `.glassEffect(in: .capsule)`.

- [ ] **Step 1: Write the failing localization test**

```swift
@Test(arguments: [
    ("hud.hint", "Yazmak için Return, Tab veya oklar · Kapatmak için Esc"),
    ("hud.permissionMissing", "Keypad'in yazabilmesi için Erişilebilirlik izni gerekiyor"),
    ("hud.backspace.accessibilityLabel", "Sil"),
    ("hud.target.accessibilityLabel", "%@ uygulamasına yazılıyor"),
    ("notice.secureInput", "Güvenli giriş açıkken Keypad yazamaz, örneğin bir şifre alanında"),
])
func hudStringsAreTranslatedToTurkish(key: String, turkish: String) throws {
    let path = try #require(Bundle.keypadUI.path(forResource: "tr", ofType: "lproj"))
    let bundle = try #require(Bundle(path: path))
    #expect(bundle.localizedString(forKey: key, value: nil, table: nil) == turkish)
}
```

- [ ] **Step 2: Run to verify failure** — `--filter hudStringsAreTranslatedToTurkish` → 5 failures.
- [ ] **Step 3: Add the catalog entries, the four views and the glossary line.**
- [ ] **Step 4: Run to verify pass** — 5 cases pass; whole package green; lint clean.
- [ ] **Step 5: Commit** — `feat(ui): add the keypad HUD and the notice view`

---

### Task 10: Wire the session into the app

**Files:**
- Create: `Keypad/AppDelegate.swift`, `Keypad/HUDCaptureSurface.swift`
- Modify: `Keypad/KeypadApp.swift` (add `@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate`)

**Interfaces:**
- Consumes: everything above.
- Produces: `@MainActor final class HUDCaptureSurface: CaptureSurface` — owns `KeypadHUDModel`, an `NSHostingView(rootView: KeypadHUDView(model:))` and a `CapturePanelController(content:)`; `show`/`render` call `model.decimalSeparator = provider.decimalSeparator` then `model.apply(hud)`; forwards `hide`, `makeKey`, `isKey`.
- Produces: `@MainActor final class AppDelegate: NSObject, NSApplicationDelegate` — composition root: builds every adapter, `SessionRunner(configuration: SessionConfiguration(), …)`, a `NoticePanelController` whose content is `NSHostingView(rootView: NoticeView(notice:))`; connects `CarbonHotkey.onPress → runner.shortcutPressed()`, `CapturePanelController.onTouch → runner.receive(_:)`, `KeyboardMonitor` started for the app's lifetime with `runner.receive(_:)`; on launch calls `permission.requestPostEventAccess()` when `!permission.canPostEvents`; `applicationWillTerminate` calls `surface.hide()`.

- [ ] **Step 1: Write the three files.**
- [ ] **Step 2: Termination restores the pointer** — confirm by reading `applicationWillTerminate` → `surface.hide()` → `CGAssociateMouseAndMouseCursorPosition(1)` (Task 8).
- [ ] **Step 3: Signed build and team check** (AGENTS.md §10) → `** BUILD SUCCEEDED **`, `TeamIdentifier=4HYL3L2W4Z`.
- [ ] **Step 4: Smoke launch** — `open build/DerivedData/Build/Products/Debug/Keypad.app`; `pgrep -x Keypad` prints a PID; quit it.
- [ ] **Step 5: Lint, full tests, commit** — `feat(app): wire the keypad session into the app`

---

### Task 11: QA with the PM, tuning and RFC record

**Files:**
- Modify: `docs/rfcs/0002-keypad-session.md` (append `## QA results` and set the final `secureInputPolicy`), `Packages/KeypadKit/Sources/KeypadCore/Session/SessionConfiguration.swift` (only if QA changes a default), constants in Tasks 2/7 (only if QA shows a need)

- [ ] **Step 1: Prepare** — signed Release build installed once (one build location), Accessibility granted to it by the PM.
- [ ] **Step 2: Run the RFC's QA matrix with the PM** — TextEdit, Notes, Safari and Chrome address bars, Google Sheets (Tab, Return, arrows, ⇧Tab), Claude (repeated commits), Numbers, a full-screen app, two displays if available, Turkish and US layouts (separator shown and typed), dark mode, ⌘Tab mid-number (number discarded), Esc, shortcut with a pending number, a password field. Record each result in a table.
- [ ] **Step 3: Decide the secure-input case** — shortcut never arrives → keep `.notify` (moot) and note it for RFC-0005; arrives and typing blocked → keep `.notify`; arrives and typing works → set `.open`. Update the RFC's Risks row accordingly.
- [ ] **Step 4: Tune only what QA proved wrong** — each change gets a failing test first (Task 2 or Task 4 style) and a line in `## QA results`.
- [ ] **Step 5: Full verification** — lint, `swift test`, signed build + team check.
- [ ] **Step 6: Commit, mark RFC-0002 Implemented** (RFC header and `docs/rfcs/README.md` index), merge into `develop` with `--no-ff`, then ask the PM before pushing.
