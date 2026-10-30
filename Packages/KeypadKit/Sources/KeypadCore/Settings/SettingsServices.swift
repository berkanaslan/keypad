@MainActor
public protocol SettingsStore {
    func load() -> KeypadSettings
    func save(_ settings: KeypadSettings)
}

@MainActor
public protocol HotkeyRegistrar: AnyObject {
    /// Registers `shortcut` in place of any earlier one. Returns `false` when macOS refuses it.
    @discardableResult func register(_ shortcut: Shortcut) -> Bool
    func unregister()
}

public enum LoginItemStatus: Equatable, Sendable {
    case off, on, requiresApproval
}

@MainActor
public protocol LoginItemController {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

/// Plays a pattern or sound once while the user chooses it, whatever the switches say.
@MainActor
public protocol FeedbackPreview {
    func preview(_ pattern: HapticPattern)
    func preview(_ sound: KeySound)
}

@MainActor
public protocol ShortcutNaming {
    func name(for shortcut: Shortcut) -> String
}
