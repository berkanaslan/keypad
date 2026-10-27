import Testing

@testable import KeypadCore

private let chrome = AppIdentity(processID: 42, bundleIdentifier: "com.google.Chrome", name: "Chrome")

@MainActor
final class SessionHarness {
    let surface = FakeSurface()
    let focus = FakeFocus()
    let keystrokes = FakeKeystrokes()
    let feedback = FakeFeedback()
    let notices = FakeNotices()
    let permission = FakePermission()
    let secureInput = FakeSecureInput()
    let runner: SessionRunner

    init(isSticky: Bool = true) {
        var configuration = SessionConfiguration()
        configuration.isSticky = isSticky
        focus.frontmost = chrome
        runner = SessionRunner(
            configuration: configuration,
            surface: surface,
            focus: focus,
            keystrokes: keystrokes,
            feedback: feedback,
            notices: notices,
            permission: permission,
            secureInput: secureInput
        )
    }

    func tapSeven() {
        let point = TrackpadPoint(x: 0.1, y: 0.95)
        runner.receive(TouchSample(id: 1, phase: .began, point: point, time: 0))
        runner.receive(TouchSample(id: 1, phase: .ended, point: point, time: 0.1))
    }
}

enum ExitPath: CaseIterable {
    case escape
    case shortcut
    case nonStickyCommit
    case interruption
    case failedHandOff
    case failedReclaim

    var isSticky: Bool { self != .nonStickyCommit }

    @MainActor func run(on harness: SessionHarness) {
        harness.runner.shortcutPressed()
        switch self {
        case .escape:
            harness.runner.receive(.escape)
        case .shortcut:
            harness.runner.shortcutPressed()
        case .nonStickyCommit:
            harness.runner.receive(.commit(.tab))
            harness.focus.completeHandOff(true)
            harness.keystrokes.completeSend()
        case .interruption:
            harness.focus.onInterruption?()
        case .failedHandOff:
            harness.runner.receive(.commit(.tab))
            harness.focus.completeHandOff(false)
        case .failedReclaim:
            harness.runner.receive(.commit(.tab))
            harness.focus.completeHandOff(true)
            harness.keystrokes.completeSend()
            harness.focus.completeReclaim(false)
        }
    }
}

@MainActor
@Suite struct SessionRunnerTests {
    private let harness = SessionHarness()

    @Test func shortcutOpensTheSurfaceOverTheFrontmostApp() {
        harness.runner.shortcutPressed()

        #expect(harness.surface.log == ["show"])
        #expect(harness.focus.watching == chrome)
    }

    @Test func stickyCommitTypesThenReclaimsAndMakesKey() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()

        #expect(harness.keystrokes.sent == [[.commit(.tab)]])
        #expect(harness.surface.log.last == "makeKey")

        harness.focus.completeReclaim(true)

        #expect(harness.runner.state == .capturing)
    }

    @Test func reclaimWaitsUntilTypedKeysAreDelivered() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.digit(7))
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)

        #expect(harness.keystrokes.sent == [[.keypadDigit(7), .commit(.tab)]])
        #expect(harness.focus.reclaimCount == 0)
        #expect(harness.surface.log.last != "makeKey")

        harness.keystrokes.completeSend()

        #expect(harness.focus.reclaimCount == 1)
        #expect(harness.surface.log.last == "makeKey")
    }

    @Test func closeWaitsUntilTypedKeysAreDelivered() {
        let harness = SessionHarness(isSticky: false)
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)

        #expect(harness.surface.log.last != "hide")

        harness.keystrokes.completeSend()

        #expect(harness.surface.log.last == "hide")
        #expect(harness.runner.state == .idle)
    }

    @Test func interruptionWhileTypingDoesNotReclaim() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.focus.onInterruption?()
        harness.keystrokes.completeSend()

        #expect(harness.focus.reclaimCount == 0)
        #expect(harness.runner.state == .idle)
    }

    @Test func shortcutDuringDeliveryWaitIsIgnored() {
        let harness = SessionHarness(isSticky: false)
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        let log = harness.surface.log
        let watchCount = harness.focus.beginWatchingCount

        harness.runner.shortcutPressed()

        #expect(harness.surface.log == log)
        #expect(harness.focus.beginWatchingCount == watchCount)

        harness.keystrokes.completeSend()

        #expect(harness.surface.log.last == "hide")
        #expect(harness.runner.state == .idle)
        #expect(harness.focus.watching == nil)
    }

    @Test func shortcutOpensAgainOnceTypedKeysAreDelivered() {
        let harness = SessionHarness(isSticky: false)
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()

        harness.runner.shortcutPressed()

        #expect(harness.runner.state == .capturing)
        #expect(harness.surface.log.last == "show")
    }

    @Test func interruptionDuringDeliveryWaitDoesNotBlockTheNextShortcut() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.focus.onInterruption?()

        harness.runner.shortcutPressed()
        harness.keystrokes.completeSend()

        #expect(harness.runner.state == .capturing)
        #expect(harness.surface.log.last == "show")
    }

    @Test func tapDuringReclaimIsHandledAndTheLateReclaimIsIgnored() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()
        #expect(harness.runner.state == .reclaiming)

        harness.tapSeven()

        #expect(harness.runner.state == .capturing)
        #expect(harness.surface.log.last == "render")

        harness.surface.isKey = false
        harness.focus.completeReclaim(false)

        #expect(harness.runner.state == .capturing)
        #expect(harness.surface.log.last == "render")
    }

    @Test func commitAfterATapDuringReclaimHandsOffAgainAndDropsTheLateReclaim() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()

        harness.tapSeven()
        harness.runner.receive(.commit(.returnKey))

        #expect(harness.runner.state == .committing)

        harness.focus.completeReclaim(true, issued: 0)

        #expect(harness.runner.state == .committing)

        harness.focus.completeHandOff(true)

        #expect(harness.keystrokes.sent.last == [.keypadDigit(7), .commit(.returnKey)])
    }

    @Test func reclaimCountsAsFailedWhenThePanelIsNotKey() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()
        harness.surface.isKey = false
        harness.focus.completeReclaim(true)

        #expect(harness.runner.state == .idle)
        #expect(harness.surface.log.last == "hide")
    }

    @Test func failedHandOffTypesNothing() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(false)

        #expect(harness.keystrokes.sent.isEmpty)
        #expect(harness.runner.state == .idle)
    }

    @Test func staleHandOffCompletionFromAnInterruptedSessionIsIgnored() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.onInterruption?()
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))

        harness.focus.completeHandOff(true, issued: 0)

        #expect(harness.keystrokes.sent.isEmpty)
        #expect(harness.runner.state == .committing)

        harness.focus.completeHandOff(true, issued: 1)

        #expect(harness.keystrokes.sent == [[.commit(.tab)]])
    }

    @Test func staleReclaimCompletionIsIgnored() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()
        harness.focus.onInterruption?()
        harness.runner.shortcutPressed()
        harness.runner.receive(.commit(.tab))
        harness.focus.completeHandOff(true)
        harness.keystrokes.completeSend()

        harness.focus.completeReclaim(true, issued: 0)

        #expect(harness.runner.state == .reclaiming)

        harness.focus.completeReclaim(true, issued: 1)

        #expect(harness.runner.state == .capturing)
    }

    @Test(arguments: ExitPath.allCases)
    func everyExitPathHidesTheSurface(path: ExitPath) {
        let harness = SessionHarness(isSticky: path.isSticky)

        path.run(on: harness)

        #expect(harness.runner.state == .idle)
        #expect(harness.surface.log.last == "hide")
        #expect(harness.focus.watching == nil)
    }

    @Test func escapeReturnsFocusToTheTarget() {
        harness.runner.shortcutPressed()
        harness.runner.receive(.escape)

        #expect(harness.focus.returnedTo == chrome)
    }

    @Test func keysAreSwallowedOnlyDuringASession() {
        #expect(harness.runner.receive(.digit(1)) == false)

        harness.runner.shortcutPressed()

        #expect(harness.runner.receive(.digit(1)) == true)
    }

    @Test func noticeShownForSecureInput() {
        harness.secureInput.isSecureInputOn = true
        harness.runner.shortcutPressed()

        #expect(harness.notices.shown == [.secureInput])
        #expect(harness.surface.log.isEmpty)
    }
}
