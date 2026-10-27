import os

/// Feeds events to the `SessionEngine` and carries out its effects against the system service protocols.
@MainActor
public final class SessionRunner {
    private var engine: SessionEngine
    private let surface: CaptureSurface
    private let focus: FocusController
    private let keystrokes: KeystrokeSender
    private let feedback: FeedbackPlayer
    private let notices: NoticeSurface
    private let permission: PermissionChecker
    private let secureInput: SecureInputChecker
    private let logger = Logger(subsystem: "io.berkan.keypad", category: "session")
    /// Advances when a session closes or a hand-off, typing or reclaim starts, so a stale completion is dropped.
    private var generation = 0
    /// The generation of the keystrokes being delivered; it stops matching `generation` once anything supersedes them.
    private var deliveringGeneration: Int?
    private var isDelivering: Bool { deliveringGeneration == generation }

    public var state: SessionState { engine.state }

    public init(
        configuration: SessionConfiguration,
        surface: CaptureSurface,
        focus: FocusController,
        keystrokes: KeystrokeSender,
        feedback: FeedbackPlayer,
        notices: NoticeSurface,
        permission: PermissionChecker,
        secureInput: SecureInputChecker
    ) {
        engine = SessionEngine(configuration: configuration)
        self.surface = surface
        self.focus = focus
        self.keystrokes = keystrokes
        self.feedback = feedback
        self.notices = notices
        self.permission = permission
        self.secureInput = secureInput
        focus.onInterruption = { [weak self] in self?.send(.interrupted) }
    }

    public func shortcutPressed() {
        guard !isDelivering else { return }
        send(
            .shortcutPressed(
                ShortcutContext(
                    frontmost: focus.frontmost,
                    isKeypadFrontmost: focus.isKeypadFrontmost,
                    isSecureInputOn: secureInput.isSecureInputOn,
                    canPostEvents: permission.canPostEvents
                )
            )
        )
    }

    public func receive(_ sample: TouchSample) {
        send(.touch(sample))
    }

    /// Returns `true` when the key belongs to the session and must not reach other apps.
    @discardableResult
    public func receive(_ key: KeyInput) -> Bool {
        let swallowsKey = engine.state != .idle
        send(.key(key))
        return swallowsKey
    }

    private func send(_ event: SessionEvent) {
        let previous = engine.state
        let effects = engine.handle(event)
        let current = engine.state
        if current != previous {
            let (old, new) = (String(describing: previous), String(describing: current))
            logger.info("\(old, privacy: .public) → \(new, privacy: .public)")
        }
        perform(effects[...])
    }

    /// Effects after `.type` wait for the keystrokes to be delivered, so focus cannot move before they are dispatched.
    private func perform(_ effects: ArraySlice<SessionEffect>) {
        var remaining = effects
        while let effect = remaining.popFirst() {
            switch effect {
            case .showCapture(let hud):
                focus.beginWatching(target: hud.target)
                surface.show(hud)
            case .render(let hud):
                surface.render(hud)
            case .hideCapture(let target):
                generation += 1
                surface.hide()
                focus.stopWatching()
                if let target { focus.returnFocus(to: target) }
            case .showNotice(let notice):
                notices.show(notice)
            case .feedback(let event):
                feedback.play(event)
            case .handOff(let target):
                generation += 1
                let issued = generation
                focus.handOff(to: target) { [weak self] succeeded in
                    guard let self, generation == issued else { return }
                    send(.handOffFinished(succeeded: succeeded))
                }
            case .type(let keys):
                generation += 1
                let issued = generation
                let followUp = remaining
                deliveringGeneration = issued
                keystrokes.send(keys) { [weak self] in
                    guard let self, generation == issued else { return }
                    deliveringGeneration = nil
                    perform(followUp)
                }
                return
            case .reclaimFocus:
                generation += 1
                let issued = generation
                focus.reclaim { [weak self] succeeded in
                    guard let self, generation == issued else { return }
                    send(.reclaimFinished(succeeded: succeeded && surface.isKey))
                }
                surface.makeKey()
            }
        }
    }
}
