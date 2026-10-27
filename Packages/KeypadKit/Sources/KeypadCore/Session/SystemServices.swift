/// The panel that captures the trackpad and shows the HUD.
@MainActor
public protocol CaptureSurface: AnyObject {
    func show(_ hud: HUDState)
    func render(_ hud: HUDState)
    func hide()
    func makeKey()
    var isKey: Bool { get }
}

/// Moves keyboard focus between Keypad and the target app, and reports when the target is lost.
@MainActor
public protocol FocusController: AnyObject {
    var frontmost: AppIdentity? { get }
    var isKeypadFrontmost: Bool { get }
    /// Called when focus is lost, the target quits, the display configuration changes or the screen locks.
    var onInterruption: (@MainActor () -> Void)? { get set }

    func beginWatching(target: AppIdentity)
    func stopWatching()
    func handOff(to target: AppIdentity, completion: @escaping @MainActor (Bool) -> Void)
    func reclaim(completion: @escaping @MainActor (Bool) -> Void)
    func returnFocus(to target: AppIdentity)
}

@MainActor
public protocol KeystrokeSender {
    /// `completion` runs asynchronously, never from inside `send`, once the keystrokes can be assumed delivered
    /// to the app that is frontmost now.
    func send(_ keystrokes: [Keystroke], completion: @escaping @MainActor () -> Void)
}

@MainActor
public protocol FeedbackPlayer {
    func play(_ event: FeedbackEvent)
}

@MainActor
public protocol NoticeSurface {
    func show(_ notice: Notice)
}

@MainActor
public protocol PermissionChecker {
    var canPostEvents: Bool { get }
    func requestPostEventAccess()
}

@MainActor
public protocol SecureInputChecker {
    var isSecureInputOn: Bool { get }
}

@MainActor
public protocol DecimalSeparatorProvider {
    var decimalSeparator: String { get }
}
