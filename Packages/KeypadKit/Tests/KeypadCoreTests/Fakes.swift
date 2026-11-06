@testable import KeypadCore

@MainActor
final class FakeSurface: CaptureSurface {
    private(set) var log: [String] = []
    var isKey = true

    func show(_ hud: HUDState) { log.append("show") }
    func render(_ hud: HUDState) { log.append("render") }
    func hide() { log.append("hide") }
    func makeKey() { log.append("makeKey") }
}

@MainActor
final class FakeFocus: FocusController {
    var frontmost: AppIdentity?
    var isKeypadFrontmost = false
    var onInterruption: (@MainActor () -> Void)?
    private(set) var watching: AppIdentity?
    private(set) var returnedTo: AppIdentity?
    private(set) var beginWatchingCount = 0

    private var handOffCompletions: [@MainActor (Bool) -> Void] = []
    private var reclaimCompletions: [@MainActor (Bool) -> Void] = []

    var reclaimCount: Int { reclaimCompletions.count }

    func beginWatching(target: AppIdentity) {
        watching = target
        beginWatchingCount += 1
    }
    func stopWatching() { watching = nil }
    func handOff(to target: AppIdentity, completion: @escaping @MainActor (Bool) -> Void) {
        handOffCompletions.append(completion)
    }
    func reclaim(completion: @escaping @MainActor (Bool) -> Void) { reclaimCompletions.append(completion) }
    func returnFocus(to target: AppIdentity) { returnedTo = target }

    func completeHandOff(_ succeeded: Bool) { handOffCompletions.last?(succeeded) }
    func completeHandOff(_ succeeded: Bool, issued index: Int) { handOffCompletions[index](succeeded) }
    func completeReclaim(_ succeeded: Bool) { reclaimCompletions.last?(succeeded) }
    func completeReclaim(_ succeeded: Bool, issued index: Int) { reclaimCompletions[index](succeeded) }
}

@MainActor
final class FakeKeystrokes: KeystrokeSender {
    private(set) var sent: [[Keystroke]] = []

    private var completions: [@MainActor () -> Void] = []

    func send(_ keystrokes: [Keystroke], completion: @escaping @MainActor () -> Void) {
        sent.append(keystrokes)
        completions.append(completion)
    }

    func completeSend() { completions.last?() }
}

@MainActor
final class FakeFeedback: FeedbackPlayer {
    private(set) var played: [FeedbackEvent] = []

    func play(_ event: FeedbackEvent) { played.append(event) }
}

@MainActor
final class FakeNotices: NoticeSurface {
    private(set) var shown: [Notice] = []

    func show(_ notice: Notice) { shown.append(notice) }
}

@MainActor
final class FakePermission: PermissionChecker {
    var canPostEvents = true
    private(set) var settingsOpens = 0

    func requestPostEventAccess() {}
    func openPermissionSettings() { settingsOpens += 1 }
}

@MainActor
final class FakeSecureInput: SecureInputChecker {
    var isSecureInputOn = false
}
