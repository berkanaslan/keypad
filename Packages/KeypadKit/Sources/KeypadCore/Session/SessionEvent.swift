/// What the system reports at the moment the shortcut is pressed.
public struct ShortcutContext: Equatable, Sendable {
    public let frontmost: AppIdentity?
    public let isKeypadFrontmost: Bool
    public let isSecureInputOn: Bool
    public let canPostEvents: Bool

    public init(frontmost: AppIdentity?, isKeypadFrontmost: Bool, isSecureInputOn: Bool, canPostEvents: Bool) {
        self.frontmost = frontmost
        self.isKeypadFrontmost = isKeypadFrontmost
        self.isSecureInputOn = isSecureInputOn
        self.canPostEvents = canPostEvents
    }
}

public enum SessionEvent: Equatable, Sendable {
    case shortcutPressed(ShortcutContext)
    case touch(TouchSample)
    case key(KeyInput)
    case handOffFinished(succeeded: Bool)
    case reclaimFinished(succeeded: Bool)
    /// Focus was lost, the target quit, the display configuration changed or the screen locked.
    case interrupted
    case permissionSettingsRequested
}
