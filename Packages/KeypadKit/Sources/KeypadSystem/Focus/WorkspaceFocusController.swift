import AppKit
import KeypadCore
import os

@MainActor
public final class WorkspaceFocusController: FocusController {
    private enum Interruption: String {
        case otherAppActivated = "another app activated"
        case targetTerminated = "target terminated"
        case sessionResigned = "session resigned"
        case screensChanged = "screens changed"
        case keypadResignedActive = "Keypad resigned active"
    }

    private struct Subscription {
        let center: NotificationCenter
        let token: any NSObjectProtocol
    }

    private struct ActiveHandOff {
        let target: AppIdentity
        let started: ContinuousClock.Instant
        let completion: @MainActor (Bool) -> Void
    }

    public var onInterruption: (@MainActor () -> Void)?

    private let settleDelay: Duration
    private let handOffTimeout: Duration
    private let reclaimCheck: Duration
    private let ownProcessID = ProcessInfo.processInfo.processIdentifier
    private let logger = Logger(subsystem: "io.berkan.keypad", category: "focus")
    private var watchedTarget: AppIdentity?
    private var watchGeneration = 0
    private var watchSubscriptions: [Subscription] = []
    private var activeHandOff: ActiveHandOff?
    private var handOffActivation: Subscription?
    private var pendingTask: Task<Void, Never>?
    /// True from the start of a hand-off until the reclaim check, while Keypad is meant to be inactive.
    private var isKeypadYielded = false

    public init(
        settleDelay: Duration = .milliseconds(60),
        handOffTimeout: Duration = .seconds(1.5),
        reclaimCheck: Duration = .milliseconds(150)
    ) {
        self.settleDelay = settleDelay
        self.handOffTimeout = handOffTimeout
        self.reclaimCheck = reclaimCheck
    }

    isolated deinit {
        stopWatching()
    }

    public var frontmost: AppIdentity? {
        NSWorkspace.shared.frontmostApplication.map { AppIdentity($0) }
    }

    public var isKeypadFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == ownProcessID
    }

    public func beginWatching(target: AppIdentity) {
        removeWatchSubscriptions()
        watchedTarget = target
        let workspace = NSWorkspace.shared.notificationCenter
        watchSubscriptions = [
            observe(NSWorkspace.didActivateApplicationNotification, on: workspace) { [weak self] note in
                let pid = processID(of: note)
                MainActor.assumeIsolated { self?.applicationDidActivate(pid) }
            },
            observe(NSWorkspace.didTerminateApplicationNotification, on: workspace) { [weak self] note in
                let pid = processID(of: note)
                MainActor.assumeIsolated { self?.applicationDidTerminate(pid) }
            },
            observe(NSWorkspace.sessionDidResignActiveNotification, on: workspace) { [weak self] _ in
                MainActor.assumeIsolated { self?.interrupt(.sessionResigned) }
            },
            observe(NSApplication.didChangeScreenParametersNotification, on: .default) { [weak self] _ in
                MainActor.assumeIsolated { self?.interrupt(.screensChanged) }
            },
            observe(NSApplication.didResignActiveNotification, on: .default) { [weak self] _ in
                MainActor.assumeIsolated { self?.keypadDidResignActive() }
            },
        ]
    }

    public func stopWatching() {
        removeWatchSubscriptions()
        cancelPending()
    }

    public func handOff(to target: AppIdentity, completion: @escaping @MainActor (Bool) -> Void) {
        cancelPending()
        isKeypadYielded = true
        activeHandOff = ActiveHandOff(target: target, started: .now, completion: completion)
        guard let app = NSRunningApplication(processIdentifier: target.processID), !app.isTerminated else {
            failHandOffLater("target is not running")
            return
        }
        handOffActivation = observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter
        ) { [weak self] note in
            let pid = processID(of: note)
            MainActor.assumeIsolated { self?.handOffTargetDidActivate(pid) }
        }
        NSApplication.shared.yieldActivation(to: app)
        guard app.activate(from: .current, options: []) else {
            failHandOffLater("activation refused")
            return
        }
        pendingTask = schedule(after: handOffTimeout) { [weak self] in
            self?.finishHandOff(succeeded: false, outcome: "timed out waiting for activation")
        }
    }

    public func reclaim(completion: @escaping @MainActor (Bool) -> Void) {
        cancelPending()
        isKeypadYielded = true
        let started = ContinuousClock.now
        NSApplication.shared.activate()
        pendingTask = schedule(after: reclaimCheck) { [weak self] in
            guard let self else { return }
            pendingTask = nil
            isKeypadYielded = false
            let isActive = NSApplication.shared.isActive
            let elapsed = milliseconds(since: started)
            logger.info("Reclaim checked after \(elapsed) ms, active: \(isActive)")
            completion(isActive)
        }
    }

    public func returnFocus(to target: AppIdentity) {
        guard let app = NSRunningApplication(processIdentifier: target.processID), !app.isTerminated else { return }
        NSApplication.shared.yieldActivation(to: app)
        app.activate(from: .current, options: [])
    }

    private func applicationDidActivate(_ pid: Int32?) {
        guard let pid, pid != ownProcessID, pid != activeHandOff?.target.processID else { return }
        interrupt(.otherAppActivated)
    }

    private func applicationDidTerminate(_ pid: Int32?) {
        guard let pid, pid == watchedTarget?.processID else { return }
        interrupt(.targetTerminated)
    }

    private func keypadDidResignActive() {
        guard !isKeypadYielded else { return }
        interrupt(.keypadResignedActive)
    }

    private func interrupt(_ reason: Interruption) {
        guard watchedTarget != nil else { return }
        let generation = watchGeneration
        Task { [weak self] in
            guard let self, generation == watchGeneration else { return }
            logger.info("Interrupted: \(reason.rawValue, privacy: .public)")
            onInterruption?()
        }
    }

    private func handOffTargetDidActivate(_ pid: Int32?) {
        guard let pid, let handOff = activeHandOff, handOffActivation != nil, pid == handOff.target.processID else {
            return
        }
        removeHandOffActivation()
        let name = handOff.target.name
        let elapsed = milliseconds(since: handOff.started)
        logger.info("Hand-off target \(name, privacy: .public) activated after \(elapsed) ms")
        pendingTask?.cancel()
        pendingTask = schedule(after: settleDelay) { [weak self] in
            self?.finishHandOff(succeeded: true, outcome: "settled")
        }
    }

    private func failHandOffLater(_ outcome: String) {
        pendingTask = schedule(after: .zero) { [weak self] in
            self?.finishHandOff(succeeded: false, outcome: outcome)
        }
    }

    private func finishHandOff(succeeded: Bool, outcome: String) {
        guard let handOff = activeHandOff else { return }
        activeHandOff = nil
        pendingTask = nil
        removeHandOffActivation()
        if !succeeded { isKeypadYielded = false }
        let name = handOff.target.name
        let elapsed = milliseconds(since: handOff.started)
        if succeeded {
            logger.info("Hand-off to \(name, privacy: .public) succeeded after \(elapsed) ms")
        } else {
            logger.error(
                "Hand-off to \(name, privacy: .public) failed after \(elapsed) ms: \(outcome, privacy: .public)")
        }
        handOff.completion(succeeded)
    }

    private func cancelPending() {
        pendingTask?.cancel()
        pendingTask = nil
        activeHandOff = nil
        isKeypadYielded = false
        removeHandOffActivation()
    }

    private func removeWatchSubscriptions() {
        for subscription in watchSubscriptions {
            subscription.center.removeObserver(subscription.token)
        }
        watchSubscriptions = []
        watchedTarget = nil
        watchGeneration += 1
    }

    private func removeHandOffActivation() {
        if let handOffActivation { handOffActivation.center.removeObserver(handOffActivation.token) }
        handOffActivation = nil
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> Subscription {
        Subscription(center: center, token: center.addObserver(forName: name, object: nil, queue: .main, using: block))
    }

    /// Runs `action` on a later main-actor turn, even when `delay` is zero.
    private func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    private func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let elapsed = start.duration(to: .now).components
        return Int(elapsed.seconds) * 1000 + Int(elapsed.attoseconds / 1_000_000_000_000_000)
    }
}

private func processID(of notification: Notification) -> Int32? {
    (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
}
