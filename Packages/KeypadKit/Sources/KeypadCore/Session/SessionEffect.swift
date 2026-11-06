public enum Notice: Equatable, Sendable {
    case secureInput
    case permissionGranted
}

public enum FeedbackEvent: Equatable, Sendable {
    case touchDown
    case keyAccepted
}

/// Whether the trackpad drives the keypad, with the pointer frozen, or the pointer, as a normal trackpad.
public enum PointerMode: Equatable, Sendable {
    case keypad
    case pointer
}

public enum MousePassThrough: Equatable, Sendable {
    case on
    /// A tap-to-click click arrives just after the finger lifts, so it needs a moment to get through (RFC-0000 F15).
    case offAfterGrace
    case offNow
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
    public let showsPointerHint: Bool

    public init(
        target: AppIdentity,
        layout: Layout,
        buffer: EntryBuffer,
        highlightedCell: Layout.Cell?,
        showsPermissionWarning: Bool,
        permissionNudges: Int = 0,
        showsPointerHint: Bool = false
    ) {
        self.target = target
        self.layout = layout
        self.buffer = buffer
        self.highlightedCell = highlightedCell
        self.showsPermissionWarning = showsPermissionWarning
        self.permissionNudges = permissionNudges
        self.showsPointerHint = showsPointerHint
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
    case pointer(PointerMode)
    case mousePassThrough(MousePassThrough)
    case releaseFocus(to: AppIdentity)
}
