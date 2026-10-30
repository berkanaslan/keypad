public enum SessionState: Equatable, Sendable {
    case idle
    case capturing
    case committing
    case reclaiming
}

/// The session rules as a pure reducer: events in, effects out. It touches nothing outside itself.
public struct SessionEngine: Sendable {
    public private(set) var state: SessionState = .idle

    /// The configuration of the open session; a new one is adopted only when a session opens.
    private var configuration: SessionConfiguration
    private var nextConfiguration: SessionConfiguration
    private var recognizer = TapRecognizer()
    /// Set exactly while a session is open, that is in every state but `idle`.
    private var target: AppIdentity?
    private var buffer = EntryBuffer()
    private var pending: [Keystroke] = []
    private var closesAfterTyping = false
    private var canPostEvents = false

    public init(configuration: SessionConfiguration) {
        self.configuration = configuration
        nextConfiguration = configuration
    }

    public mutating func configure(_ configuration: SessionConfiguration) {
        nextConfiguration = configuration
    }

    public mutating func handle(_ event: SessionEvent) -> [SessionEffect] {
        guard let target else {
            guard case .shortcutPressed(let context) = event else { return [] }
            return open(context)
        }
        switch (state, event) {
        case (_, .interrupted):
            return close(returnFocusTo: nil)
        case (.capturing, .shortcutPressed):
            return closeByShortcut(target: target)
        case (.capturing, .touch(let sample)):
            return handleTouch(sample, target: target)
        case (.capturing, .key(let input)):
            return handleKey(input, target: target)
        case (.committing, .handOffFinished(let succeeded)):
            return finishHandOff(succeeded: succeeded)
        case (.reclaiming, .reclaimFinished(let succeeded)):
            return finishReclaim(succeeded: succeeded, target: target)
        case (.reclaiming, .touch):
            // A touch reaches Keypad only while it is active with its panel key (F2), which proves the reclaim. A key
            // proves nothing: a non-activating panel can be key while Keypad is inactive.
            state = .capturing
            return handle(event)
        default:
            return []
        }
    }

    private mutating func open(_ context: ShortcutContext) -> [SessionEffect] {
        guard let frontmost = context.frontmost, !context.isKeypadFrontmost else { return [] }
        if context.isSecureInputOn {
            return [.showNotice(.secureInput)]
        }
        target = frontmost
        configuration = nextConfiguration
        canPostEvents = context.canPostEvents
        state = .capturing
        return [.showCapture(hud(target: frontmost))]
    }

    private mutating func handleTouch(_ sample: TouchSample, target: AppIdentity) -> [SessionEffect] {
        guard let event = recognizer.handle(sample) else { return [] }
        switch event {
        case .touchDown(let point):
            guard let cell = cell(at: point) else { return [] }
            return [.feedback(.touchDown), .render(hud(target: target, highlighting: cell))]
        case .tap(let point):
            guard let cell = cell(at: point) else { return [] }
            buffer.apply(cell.action)
            return [.feedback(.keyAccepted), .render(hud(target: target, highlighting: cell))]
        }
    }

    private mutating func handleKey(_ input: KeyInput, target: AppIdentity) -> [SessionEffect] {
        switch input {
        case .digit(let value):
            return edit(.digit(value), target: target)
        case .decimalSeparator:
            return edit(.decimalSeparator, target: target)
        case .deleteBackward:
            return edit(.backspace, target: target)
        case .commit(let key):
            return commit(key, target: target)
        case .escape:
            return close(returnFocusTo: target)
        case .other:
            return []
        }
    }

    private mutating func edit(_ action: KeyAction, target: AppIdentity) -> [SessionEffect] {
        buffer.apply(action)
        return [.render(hud(target: target))]
    }

    private mutating func commit(_ key: CommitKey, target: AppIdentity) -> [SessionEffect] {
        guard canPostEvents else { return [.render(hud(target: target))] }
        beginHandOff(typing: buffer.keystrokes + [.commit(key)])
        return [.render(hud(target: target)), .handOff(to: target)]
    }

    private mutating func closeByShortcut(target: AppIdentity) -> [SessionEffect] {
        guard !buffer.isEmpty else { return close(returnFocusTo: target) }
        guard canPostEvents else { return [.render(hud(target: target))] }
        closesAfterTyping = true
        beginHandOff(typing: buffer.keystrokes)
        return [.handOff(to: target)]
    }

    /// Touches are not delivered while handing off, so a contact still held here must not tap once the session resumes.
    private mutating func beginHandOff(typing keystrokes: [Keystroke]) {
        pending = keystrokes
        buffer = EntryBuffer()
        recognizer = TapRecognizer()
        state = .committing
    }

    private mutating func finishHandOff(succeeded: Bool) -> [SessionEffect] {
        guard succeeded else { return close(returnFocusTo: nil) }
        let typing = SessionEffect.type(pending)
        pending = []
        if configuration.isSticky && !closesAfterTyping {
            state = .reclaiming
            return [typing, .reclaimFocus]
        }
        return [typing] + close(returnFocusTo: nil)
    }

    private mutating func finishReclaim(succeeded: Bool, target: AppIdentity) -> [SessionEffect] {
        guard succeeded else { return close(returnFocusTo: nil) }
        state = .capturing
        return [.render(hud(target: target))]
    }

    private mutating func close(returnFocusTo focus: AppIdentity?) -> [SessionEffect] {
        state = .idle
        target = nil
        buffer = EntryBuffer()
        pending = []
        closesAfterTyping = false
        recognizer = TapRecognizer()
        return [.hideCapture(returnFocusTo: focus)]
    }

    private func cell(at point: TrackpadPoint) -> Layout.Cell? {
        configuration.activeArea.map(point).flatMap(configuration.layout.cell(at:))
    }

    private func hud(target: AppIdentity, highlighting cell: Layout.Cell? = nil) -> HUDState {
        HUDState(
            target: target,
            layout: configuration.layout,
            buffer: buffer,
            highlightedCell: cell,
            showsPermissionWarning: !canPostEvents
        )
    }
}
