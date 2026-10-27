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

    public init(
        target: AppIdentity,
        layout: Layout,
        buffer: EntryBuffer,
        highlightedCell: Layout.Cell?,
        showsPermissionWarning: Bool
    ) {
        self.target = target
        self.layout = layout
        self.buffer = buffer
        self.highlightedCell = highlightedCell
        self.showsPermissionWarning = showsPermissionWarning
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
}
