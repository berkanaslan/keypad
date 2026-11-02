import AppKit
import KeypadCore

/// Owns the local event monitors that capture the next key combination. Esc or any click cancels; the events are
/// swallowed, so a click on the recorder cancels instead of restarting it.
@MainActor
final class ShortcutCapture {
    typealias Install = @MainActor (NSEvent.EventTypeMask, @escaping (NSEvent) -> NSEvent?) -> Any?
    typealias Remove = @MainActor (Any) -> Void

    private static let escapeKeyCode: UInt16 = 53

    private let install: Install
    private let remove: Remove
    private var monitors: [Any] = []

    init(
        install: @escaping Install = { NSEvent.addLocalMonitorForEvents(matching: $0, handler: $1) },
        remove: @escaping Remove = { NSEvent.removeMonitor($0) }
    ) {
        self.install = install
        self.remove = remove
    }

    var isCapturing: Bool { !monitors.isEmpty }

    /// Replaces any capture already running, so a second press (VoiceOver bypasses the click monitor) can't leak one.
    func start(onKey: @escaping @MainActor (Shortcut) -> Void, onCancel: @escaping @MainActor () -> Void) {
        stop()
        let keys = install(.keyDown) { event in
            guard !event.isARepeat else { return nil }
            let keyCode = event.keyCode
            let modifiers = ShortcutModifiers(eventFlags: event.modifierFlags)
            MainActor.assumeIsolated {
                if keyCode == Self.escapeKeyCode {
                    onCancel()
                } else {
                    onKey(Shortcut(keyCode: keyCode, modifiers: modifiers))
                }
            }
            return nil
        }
        let clicks = install(.leftMouseDown) { _ in
            MainActor.assumeIsolated { onCancel() }
            return nil
        }
        monitors = [keys, clicks].compactMap(\.self)
    }

    func stop() {
        for monitor in monitors {
            remove(monitor)
        }
        monitors = []
    }
}
