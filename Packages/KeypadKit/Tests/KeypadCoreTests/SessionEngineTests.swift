import Testing

@testable import KeypadCore

private let chrome = AppIdentity(processID: 42, bundleIdentifier: "com.google.Chrome", name: "Chrome")

private func context(
    frontmost: AppIdentity? = chrome,
    isKeypadFrontmost: Bool = false,
    isSecureInputOn: Bool = false,
    canPost: Bool = true
) -> ShortcutContext {
    ShortcutContext(
        frontmost: frontmost,
        isKeypadFrontmost: isKeypadFrontmost,
        isSecureInputOn: isSecureInputOn,
        canPostEvents: canPost
    )
}

@discardableResult
private func open(_ engine: inout SessionEngine, canPost: Bool = true) -> [SessionEffect] {
    engine.handle(.shortcutPressed(context(canPost: canPost)))
}

private func touch(_ phase: TouchSample.Phase, x: Double, y: Double, at time: Double) -> SessionEvent {
    .touch(TouchSample(id: 1, phase: phase, point: TrackpadPoint(x: x, y: y), time: time))
}

@discardableResult
private func tap(_ engine: inout SessionEngine, x: Double, y: Double) -> [SessionEffect] {
    engine.handle(touch(.began, x: x, y: y, at: 0)) + engine.handle(touch(.ended, x: x, y: y, at: 0.1))
}

private func tapSeven(_ engine: inout SessionEngine) {
    tap(&engine, x: 0.1, y: 0.95)
}

private func commitSevenWithTab(_ engine: inout SessionEngine) {
    open(&engine)
    tapSeven(&engine)
    _ = engine.handle(.key(.commit(.tab)))
}

private func reclaim(_ engine: inout SessionEngine) {
    commitSevenWithTab(&engine)
    _ = engine.handle(.handOffFinished(succeeded: true))
}

private func lastRender(in effects: [SessionEffect]) -> HUDState? {
    for effect in effects.reversed() {
        if case .render(let hud) = effect { return hud }
    }
    return nil
}

@Suite struct SessionEngineTests {
    private var engine = SessionEngine(configuration: SessionConfiguration())

    @Test mutating func shortcutOpensOverTheFrontmostApp() {
        let effects = open(&engine)

        guard case .showCapture(let hud) = effects.first else {
            Issue.record("expected showCapture first, got \(effects)")
            return
        }
        #expect(hud.target == chrome)
        #expect(engine.state == .capturing)
    }

    @Test mutating func shortcutIsIgnoredWhenKeypadIsFrontmost() {
        let effects = engine.handle(.shortcutPressed(context(isKeypadFrontmost: true)))

        #expect(effects == [])
        #expect(engine.state == .idle)
    }

    @Test mutating func shortcutIsIgnoredWithoutFrontmostApp() {
        let effects = engine.handle(.shortcutPressed(context(frontmost: nil)))

        #expect(effects == [])
        #expect(engine.state == .idle)
    }

    @Test mutating func secureInputShowsNoticeInsteadOfOpening() {
        let effects = engine.handle(.shortcutPressed(context(isSecureInputOn: true)))

        #expect(effects == [.showNotice(.secureInput)])
        #expect(engine.state == .idle)
    }

    @Test mutating func touchDownOnACellPlaysFeedbackAndHighlights() {
        open(&engine)

        let effects = engine.handle(touch(.began, x: 0.1, y: 0.95, at: 0))

        #expect(effects.contains(.feedback(.touchDown)))
        #expect(lastRender(in: effects)?.highlightedCell?.action == .digit(7))
    }

    @Test mutating func tapAppliesTheCellAction() {
        open(&engine)

        let effects = tap(&engine, x: 0.1, y: 0.95)

        #expect(effects.contains(.feedback(.keyAccepted)))
        #expect(lastRender(in: effects)?.buffer.display(decimalSeparator: ".") == "7")
    }

    @Test mutating func touchOutsideTheActiveAreaDoesNothing() {
        var configuration = SessionConfiguration()
        configuration.activeArea = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        engine = SessionEngine(configuration: configuration)
        open(&engine)

        #expect(engine.handle(touch(.began, x: 0.2, y: 0.5, at: 0)) == [])
    }

    @Test mutating func keyboardDigitsEditTheBuffer() {
        open(&engine)

        _ = engine.handle(.key(.digit(4)))
        _ = engine.handle(.key(.decimalSeparator))
        let effects = engine.handle(.key(.deleteBackward))

        #expect(lastRender(in: effects)?.buffer.display(decimalSeparator: ".") == "4")
    }

    @Test mutating func otherKeysAreSwallowedSilently() {
        open(&engine)

        #expect(engine.handle(.key(.other)) == [])
        #expect(engine.state == .capturing)
    }

    @Test mutating func commitHandsOffWithPendingKeystrokes() {
        open(&engine)
        tapSeven(&engine)

        let effects = engine.handle(.key(.commit(.tab)))

        #expect(effects.contains(.handOff(to: chrome)))
        #expect(engine.state == .committing)
    }

    @Test mutating func handOffTypesThenReclaimsWhenSticky() {
        commitSevenWithTab(&engine)

        let effects = engine.handle(.handOffFinished(succeeded: true))

        #expect(effects == [.type([.keypadDigit(7), .commit(.tab)]), .reclaimFocus])
        #expect(engine.state == .reclaiming)
    }

    @Test mutating func handOffTypesThenClosesWhenNotSticky() {
        var configuration = SessionConfiguration()
        configuration.isSticky = false
        engine = SessionEngine(configuration: configuration)
        commitSevenWithTab(&engine)

        let effects = engine.handle(.handOffFinished(succeeded: true))

        #expect(effects == [.type([.keypadDigit(7), .commit(.tab)]), .hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
    }

    @Test mutating func emptyCommitStillSendsTheKey() {
        open(&engine)
        _ = engine.handle(.key(.commit(.returnKey)))

        let effects = engine.handle(.handOffFinished(succeeded: true))

        #expect(effects.first == .type([.commit(.returnKey)]))
    }

    @Test mutating func failedHandOffClosesWithoutTyping() {
        commitSevenWithTab(&engine)

        let effects = engine.handle(.handOffFinished(succeeded: false))

        #expect(effects == [.hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
    }

    @Test mutating func reclaimReturnsToCapturingWithAnEmptyBuffer() {
        commitSevenWithTab(&engine)
        _ = engine.handle(.handOffFinished(succeeded: true))

        let effects = engine.handle(.reclaimFinished(succeeded: true))

        #expect(engine.state == .capturing)
        #expect(lastRender(in: effects)?.buffer.isEmpty == true)
    }

    @Test mutating func reclaimFailureCloses() {
        commitSevenWithTab(&engine)
        _ = engine.handle(.handOffFinished(succeeded: true))

        let effects = engine.handle(.reclaimFinished(succeeded: false))

        #expect(effects == [.hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
    }

    @Test mutating func tapDuringReclaimIsAppliedAndResumesCapturing() {
        reclaim(&engine)

        let effects = tap(&engine, x: 0.1, y: 0.95)

        #expect(effects.contains(.feedback(.keyAccepted)))
        #expect(lastRender(in: effects)?.buffer.display(decimalSeparator: ".") == "7")
        #expect(engine.state == .capturing)
    }

    @Test mutating func touchDownDuringReclaimHighlightsTheCell() {
        reclaim(&engine)

        let effects = engine.handle(touch(.began, x: 0.1, y: 0.95, at: 0))

        #expect(effects.contains(.feedback(.touchDown)))
        #expect(lastRender(in: effects)?.highlightedCell?.action == .digit(7))
        #expect(engine.state == .capturing)
    }

    @Test(arguments: [KeyInput.digit(4), .commit(.tab), .escape])
    mutating func keysDuringReclaimAreIgnored(key: KeyInput) {
        reclaim(&engine)

        let effects = engine.handle(.key(key))

        #expect(effects == [])
        #expect(engine.state == .reclaiming)
    }

    @Test(arguments: [true, false])
    mutating func reclaimFinishedAfterATapChangesNothing(succeeded: Bool) {
        reclaim(&engine)
        tapSeven(&engine)

        let effects = engine.handle(.reclaimFinished(succeeded: succeeded))

        #expect(effects == [])
        #expect(engine.state == .capturing)
        #expect(lastRender(in: engine.handle(.key(.deleteBackward)))?.buffer.isEmpty == true)
    }

    @Test mutating func keysDuringCommitAreIgnored() {
        commitSevenWithTab(&engine)

        #expect(engine.handle(.key(.commit(.tab))) == [])
        #expect(engine.state == .committing)
    }

    @Test mutating func escapeClosesAndReturnsFocus() {
        open(&engine)
        tapSeven(&engine)

        let effects = engine.handle(.key(.escape))

        #expect(effects == [.hideCapture(returnFocusTo: chrome)])
        #expect(engine.state == .idle)
    }

    @Test mutating func shortcutWithPendingNumberTypesAndCloses() {
        open(&engine)
        tapSeven(&engine)
        _ = engine.handle(.shortcutPressed(context()))

        let effects = engine.handle(.handOffFinished(succeeded: true))

        #expect(effects == [.type([.keypadDigit(7)]), .hideCapture(returnFocusTo: nil)])
    }

    @Test mutating func shortcutWithEmptyBufferCloses() {
        open(&engine)

        let effects = engine.handle(.shortcutPressed(context()))

        #expect(effects == [.hideCapture(returnFocusTo: chrome)])
    }

    @Test mutating func shortcutWithEmptyBufferClosesWithoutPermission() {
        open(&engine, canPost: false)

        let effects = engine.handle(.shortcutPressed(context()))

        #expect(effects == [.hideCapture(returnFocusTo: chrome)])
        #expect(engine.state == .idle)
    }

    @Test mutating func fingerRestingAtCommitDoesNotTapAfterReclaim() {
        open(&engine)
        _ = engine.handle(touch(.began, x: 0.1, y: 0.95, at: 0))
        _ = engine.handle(.key(.commit(.tab)))
        _ = engine.handle(.handOffFinished(succeeded: true))
        _ = engine.handle(.reclaimFinished(succeeded: true))

        let effects = engine.handle(touch(.ended, x: 0.1, y: 0.95, at: 0.2))
        let afterwards = engine.handle(.key(.deleteBackward))

        #expect(effects == [])
        #expect(lastRender(in: afterwards)?.buffer.isEmpty == true)
    }

    @Test mutating func interruptionDuringCommitCloses() {
        commitSevenWithTab(&engine)

        let effects = engine.handle(.interrupted)

        #expect(effects == [.hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
        #expect(engine.handle(.handOffFinished(succeeded: true)) == [])
    }

    @Test mutating func newConfigurationAppliesFromTheNextSession() {
        open(&engine)
        var notSticky = SessionConfiguration()
        notSticky.isSticky = false
        engine.configure(notSticky)
        tapSeven(&engine)
        _ = engine.handle(.key(.commit(.tab)))
        #expect(engine.handle(.handOffFinished(succeeded: true)).contains(.reclaimFocus))

        _ = engine.handle(.interrupted)
        commitSevenWithTab(&engine)
        #expect(!engine.handle(.handOffFinished(succeeded: true)).contains(.reclaimFocus))
    }

    @Test mutating func interruptionDuringReclaimCloses() {
        commitSevenWithTab(&engine)
        _ = engine.handle(.handOffFinished(succeeded: true))

        let effects = engine.handle(.interrupted)

        #expect(effects == [.hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
    }

    @Test mutating func interruptionDiscardsAndCloses() {
        open(&engine)
        tapSeven(&engine)

        let effects = engine.handle(.interrupted)

        #expect(effects == [.hideCapture(returnFocusTo: nil)])
        #expect(engine.state == .idle)
    }

    @Test mutating func tapWhilePermissionIsMissingOnlyNudges() {
        open(&engine, canPost: false)

        let effects = tap(&engine, x: 0.1, y: 0.95)

        let hud = lastRender(in: effects)
        #expect(hud?.buffer.isEmpty == true)
        #expect(hud?.permissionNudges == 1)
        #expect(hud?.highlightedCell == nil)
        #expect(!effects.contains(.feedback(.touchDown)))
        #expect(!effects.contains(.feedback(.keyAccepted)))
    }

    @Test(arguments: [
        KeyInput.digit(7), .decimalSeparator, .deleteBackward, .commit(.tab), .commit(.shiftTab), .commit(.arrow(.up)),
    ])
    mutating func keyWhilePermissionIsMissingOnlyNudges(key: KeyInput) {
        open(&engine, canPost: false)

        let hud = lastRender(in: engine.handle(.key(key)))

        #expect(hud?.buffer.isEmpty == true)
        #expect(hud?.permissionNudges == 1)
        #expect(engine.state == .capturing)
    }

    @Test(arguments: [CommitKey.returnKey, .shiftReturn, .keypadEnter])
    mutating func returnOpensSettingsWhilePermissionIsMissing(key: CommitKey) {
        open(&engine, canPost: false)

        #expect(engine.handle(.key(.commit(key))) == [.hideCapture(returnFocusTo: nil), .openPermissionSettings])
        #expect(engine.state == .idle)
    }

    @Test mutating func nudgesCountUpAndResetWithTheNextSession() {
        open(&engine, canPost: false)
        tapSeven(&engine)

        #expect(lastRender(in: tap(&engine, x: 0.1, y: 0.95))?.permissionNudges == 2)

        _ = engine.handle(.key(.escape))
        guard case .showCapture(let hud) = open(&engine, canPost: false).first else {
            Issue.record("expected showCapture first")
            return
        }
        #expect(hud.permissionNudges == 0)
    }

    @Test mutating func settingsRequestClosesAndOpensSettings() {
        open(&engine, canPost: false)

        #expect(
            engine.handle(.permissionSettingsRequested) == [.hideCapture(returnFocusTo: nil), .openPermissionSettings])
        #expect(engine.state == .idle)
    }

    @Test mutating func settingsRequestAfterCloseDoesNothing() {
        #expect(engine.handle(.permissionSettingsRequested) == [])
    }

    @Test mutating func settingsRequestWithThePermissionDoesNothing() {
        open(&engine)

        #expect(engine.handle(.permissionSettingsRequested) == [])
        #expect(engine.state == .capturing)
    }
}

@Suite struct SessionPointerModeTests {
    private var engine: SessionEngine = {
        var configuration = SessionConfiguration()
        configuration.activeArea = ActiveArea(x: 0, y: 0, width: 0.5, height: 1)
        return SessionEngine(configuration: configuration)
    }()

    private mutating func wake() -> [SessionEffect] {
        let start = TrackpadPoint(x: 0.8, y: 0.5)
        let end = TrackpadPoint(x: 0.85, y: 0.5)
        return engine.handle(.touch(TouchSample(id: 9, phase: .began, point: start, time: 0)))
            + engine.handle(.touch(TouchSample(id: 9, phase: .moved, point: end, time: 0.1)))
    }

    private mutating func lift() {
        let end = TrackpadPoint(x: 0.85, y: 0.5)
        _ = engine.handle(.touch(TouchSample(id: 9, phase: .ended, point: end, time: 0.2)))
    }

    @Test mutating func wakingShowsThePointerHint() {
        open(&engine)

        let effects = wake()

        #expect(effects.contains(.pointer(.pointer)))
        #expect(lastRender(in: effects)?.showsPointerHint == true)
    }

    @Test mutating func tappingTheAreaEntersItsDigit() {
        open(&engine)
        _ = wake()
        lift()

        let hud = lastRender(in: tap(&engine, x: 0.1, y: 0.95))

        #expect(hud?.buffer.display(decimalSeparator: ".") == "7")
        #expect(hud?.showsPointerHint == false)
    }

    @Test mutating func clickInPointerModeClosesAndDiscardsTheNumber() {
        open(&engine)
        tapSeven(&engine)
        _ = wake()

        let effects = engine.handle(.clickReachedAnotherApp)

        #expect(effects == [.hideCapture(returnFocusTo: nil), .releaseFocus(to: chrome)])
        #expect(engine.state == .idle)
        guard case .showCapture(let hud) = open(&engine).first else {
            Issue.record("expected showCapture first")
            return
        }
        #expect(hud.buffer.isEmpty)
    }

    @Test mutating func clickInKeypadModeDoesNothing() {
        open(&engine)

        #expect(engine.handle(.clickReachedAnotherApp) == [])
        #expect(engine.state == .capturing)
    }

    @Test mutating func commitFromPointerModeFreezesFirst() throws {
        open(&engine)
        tapSeven(&engine)
        _ = wake()

        let effects = engine.handle(.key(.commit(.tab)))

        let frozen = try #require(effects.firstIndex(of: .pointer(.keypad)))
        let handOff = try #require(effects.firstIndex(of: .handOff(to: chrome)))
        #expect(frozen < handOff)
    }

    @Test mutating func shortcutFromPointerModeFreezesFirst() throws {
        open(&engine)
        tapSeven(&engine)
        _ = wake()

        let effects = engine.handle(.shortcutPressed(context()))

        let frozen = try #require(effects.firstIndex(of: .pointer(.keypad)))
        let handOff = try #require(effects.firstIndex(of: .handOff(to: chrome)))
        #expect(frozen < handOff)
    }

    @Test mutating func noPointerRulesWhileThePermissionIsMissing() {
        open(&engine, canPost: false)

        #expect(!wake().contains(.pointer(.pointer)))
    }
}
