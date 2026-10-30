import KeypadCore
import Testing

@testable import KeypadUI

@MainActor
@Suite struct SettingsModelTests {
    private let functionKey = Shortcut(keyCode: 105, modifiers: [])

    private var disabled: KeypadSettings {
        var settings = KeypadSettings()
        settings.isEnabled = false
        return settings
    }

    @Test func startRegistersTheSavedShortcutWhenEnabled() {
        let h = Harness()
        h.model.start()
        #expect(h.registrar.registered == .default)
    }

    @Test func startDoesNotRegisterWhenDisabled() {
        let h = Harness(saved: disabled)
        h.model.start()
        #expect(h.registrar.registered == nil)
    }

    @Test func startReportsARefusedSavedShortcut() {
        let h = Harness(registerResults: [false])
        h.model.start()
        #expect(h.model.isSavedShortcutRefused)
    }

    @Test func everyChangeIsSavedAndReported() {
        let h = Harness()
        var reported: [KeypadSettings] = []
        h.model.onChange = { reported.append($0) }
        h.model.setStaysOpenAfterTyping(false)
        #expect(h.store.saved.last?.staysOpenAfterTyping == false && reported.count == 1)
    }

    @Test func disablingUnregistersTheShortcut() {
        let h = Harness()
        h.model.start()
        h.model.setEnabled(false)
        #expect(h.registrar.registered == nil && h.store.saved.last?.isEnabled == false)
    }

    @Test func recordingSuspendsTheShortcut() {
        let h = Harness()
        h.model.start()
        h.model.startRecording()
        #expect(h.registrar.registered == nil && h.model.recorder == .recording)
    }

    @Test func validCandidateBecomesTheShortcut() {
        let h = Harness()
        h.model.start()
        h.model.startRecording()
        h.model.record(functionKey)
        #expect(h.registrar.registered == functionKey && h.store.saved.last?.shortcut == functionKey)
        #expect(h.model.recorder == .idle)
    }

    @Test func invalidCandidateKeepsRecording() {
        let h = Harness()
        h.model.startRecording()
        h.model.record(Shortcut(keyCode: 40, modifiers: [.command]))
        #expect(h.model.recorder == .invalid && h.store.saved.isEmpty)
    }

    @Test func refusedCandidateKeepsThePreviousShortcut() {
        let h = Harness(registerResults: [true, false, true])
        h.model.start()
        h.model.startRecording()
        h.model.record(functionKey)
        #expect(h.registrar.registered == .default && h.model.settings.shortcut == .default)
        #expect(h.model.recorder == .refused)
    }

    @Test func cancelRestoresTheShortcut() {
        let h = Harness()
        h.model.start()
        h.model.startRecording()
        h.model.cancelRecording()
        #expect(h.registrar.registered == .default && h.model.recorder == .idle)
    }

    @Test func recordingWhileDisabledChecksAndReleases() {
        let h = Harness(saved: disabled)
        h.model.start()
        h.model.startRecording()
        h.model.record(functionKey)
        #expect(h.registrar.registered == nil && h.store.saved.last?.shortcut == functionKey)
    }

    @Test func resetRestoresTheDefault() {
        var saved = KeypadSettings()
        saved.shortcut = functionKey
        let h = Harness(saved: saved)
        h.model.start()
        h.model.resetShortcut()
        #expect(h.model.settings.shortcut == .default)
    }

    @Test func leavingKeypadWhileRecordingRestoresTheShortcut() {
        let h = Harness()
        h.model.start()
        h.model.startRecording()
        h.model.abandonRecording()
        #expect(h.registrar.registered == .default && h.model.recorder == .idle)
    }

    @Test func leavingKeypadWhenNotRecordingChangesNothing() {
        let h = Harness(saved: disabled)
        h.model.start()
        h.model.abandonRecording()
        #expect(h.registrar.registered == nil && h.model.recorder == .idle)
    }

    @Test func disablingClearsTheRefusalMessage() {
        let h = Harness(registerResults: [false])
        h.model.start()
        h.model.setEnabled(false)
        #expect(!h.model.isSavedShortcutRefused)
    }

    @Test func choosingFeedbackPreviewsIt() {
        let h = Harness()
        h.model.setHapticPattern(.light)
        h.model.setSound(.deep)
        #expect(h.preview.previews == ["light", "deep"])
    }

    @Test func failedLoginItemChangeKeepsTheStatus() {
        let h = Harness()
        h.loginItem.shouldThrow = true
        h.model.setOpenAtLogin(true)
        #expect(h.model.loginItemStatus == .off)
    }
}
