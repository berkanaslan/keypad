import Foundation
import KeypadCore

@MainActor
public final class TimerPermissionWatcher: PermissionWatcher {
    private let interval: Duration
    private var task: Task<Void, Never>?
    private var activity: NSObjectProtocol?

    public init(interval: Duration = .seconds(1)) {
        self.interval = interval
    }

    isolated deinit {
        stop()
    }

    public func start(tick: @escaping @MainActor () -> Void) {
        stop()
        // Keypad usually has no window at this point, and App Nap would stretch the interval.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Watching for the Accessibility permission"
        )
        task = Task { [interval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                tick()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }
}
