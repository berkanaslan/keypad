public enum Notice: Equatable, Sendable {
    case secureInput
}

public enum FeedbackEvent: Equatable, Sendable {
    case touchDown
    case keyAccepted
}

/// Everything the HUD shows for one render.
public struct HUDState: Equatable, Sendable {
    public let target: AppIdentity
    public let layout: Layout
    public let buffer: EntryBuffer
    public let highlightedCell: Layout.Cell?
    public let showsPermissionWarning: Bool
    /// Rises each time the user tries to use a keypad that can't type, so the view can react to every attempt.
    public let permissionNudges: Int

    public init(
        target: AppIdentity,
        layout: Layout,
        buffer: EntryBuffer,
        highlightedCell: Layout.Cell?,
        showsPermissionWarning: Bool,
        permissionNudges: Int = 0
    ) {
        self.target = target
        self.layout = layout
        self.buffer = buffer
        self.highlightedCell = highlightedCell
        self.showsPermissionWarning = showsPermissionWarning
        self.permissionNudges = permissionNudges
    }
}

/// Work for the system layer; the engine never performs any itself.
public enum SessionEffect: Equatable, Sendable {
    case showCapture(HUDState)
    case render(HUDState)
    case hideCapture(returnFocusTo: AppIdentity?)
    case showNotice(Notice)
    case feedback(FeedbackEvent)
    case handOff(to: AppIdentity)
    case type([Keystroke])
    case reclaimFocus
    case openPermissionSettings
}
