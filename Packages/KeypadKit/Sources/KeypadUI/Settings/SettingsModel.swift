import KeypadCore
import Observation
import os

public enum ShortcutRecorderState: Equatable, Sendable {
    case idle
    case recording
    /// Still recording; the last combination broke the shortcut rule.
    case invalid
    /// Recording ended because macOS refused the combination; the previous shortcut stays.
    case refused
}

/// Holds the settings, saves every change and keeps the system-wide shortcut registered to match them.
@MainActor
@Observable
public final class SettingsModel {
    public private(set) var settings: KeypadSettings
    public private(set) var recorder = ShortcutRecorderState.idle
    public private(set) var isSavedShortcutRefused = false
    public private(set) var loginItemStatus: LoginItemStatus
    @ObservationIgnored public var onChange: (@MainActor (KeypadSettings) -> Void)?

    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private let hotkey: HotkeyRegistrar
    @ObservationIgnored private let loginItem: LoginItemController
    @ObservationIgnored private let feedback: FeedbackPreview
    @ObservationIgnored private let shortcutNames: ShortcutNaming
    @ObservationIgnored private let logger = Logger(subsystem: "io.berkan.keypad", category: "input")

    public init(
        store: SettingsStore,
        hotkey: HotkeyRegistrar,
        loginItem: LoginItemController,
        feedback: FeedbackPreview,
        shortcutNames: ShortcutNaming
    ) {
        self.store = store
        self.hotkey = hotkey
        self.loginItem = loginItem
        self.feedback = feedback
        self.shortcutNames = shortcutNames
        settings = store.load()
        loginItemStatus = loginItem.status
    }

    public var shortcutName: String {
        shortcutNames.name(for: settings.shortcut)
    }

    public func start() {
        if settings.isEnabled { registerSavedShortcut() }
    }

    public func setEnabled(_ enabled: Bool) {
        change { $0.isEnabled = enabled }
        if enabled {
            registerSavedShortcut()
        } else {
            hotkey.unregister()
            isSavedShortcutRefused = false
        }
    }

    public func setStaysOpenAfterTyping(_ staysOpen: Bool) {
        change { $0.staysOpenAfterTyping = staysOpen }
    }

    public func setActiveArea(_ area: ActiveArea) {
        change { $0.activeArea = area }
    }

    public func setHapticsOn(_ on: Bool) {
        change { $0.feedback.hapticsOn = on }
    }

    public func setHapticPattern(_ pattern: HapticPattern) {
        change { $0.feedback.hapticPattern = pattern }
        feedback.preview(pattern)
    }

    public func setSoundOn(_ on: Bool) {
        change { $0.feedback.soundOn = on }
    }

    public func setSound(_ sound: KeySound) {
        change { $0.feedback.sound = sound }
        feedback.preview(sound)
    }

    /// The current shortcut is released while recording, so pressing it records it instead of opening a session.
    public func startRecording() {
        hotkey.unregister()
        recorder = .recording
    }

    public func record(_ candidate: Shortcut) {
        guard candidate.isValid else {
            recorder = .invalid
            return
        }
        guard hotkey.register(candidate) else {
            logger.info("A new shortcut was refused by macOS")
            restoreSavedShortcut()
            recorder = .refused
            return
        }
        if !settings.isEnabled { hotkey.unregister() }
        change { $0.shortcut = candidate }
        isSavedShortcutRefused = false
        recorder = .idle
    }

    public func cancelRecording() {
        restoreSavedShortcut()
        recorder = .idle
    }

    public func resetShortcut() {
        record(.default)
    }

    /// Called when Keypad stops being the active app: key presses and clicks elsewhere never reach the recorder.
    public func abandonRecording() {
        guard recorder == .recording || recorder == .invalid else { return }
        cancelRecording()
    }

    public func setOpenAtLogin(_ open: Bool) {
        do {
            try loginItem.setEnabled(open)
        } catch {
            logger.error("Changing the login item failed")
        }
        refreshLoginItemStatus()
    }

    public func refreshLoginItemStatus() {
        loginItemStatus = loginItem.status
    }

    public func openLoginItems() {
        loginItem.openSystemSettings()
    }

    private func registerSavedShortcut() {
        isSavedShortcutRefused = !hotkey.register(settings.shortcut)
        if isSavedShortcutRefused { logger.info("The saved shortcut was refused by macOS") }
    }

    private func restoreSavedShortcut() {
        if settings.isEnabled { registerSavedShortcut() }
    }

    private func change(_ update: (inout KeypadSettings) -> Void) {
        update(&settings)
        store.save(settings)
        onChange?(settings)
    }
}
