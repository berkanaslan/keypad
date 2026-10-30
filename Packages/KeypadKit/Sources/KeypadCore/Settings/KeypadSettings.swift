/// Every user setting, with its default. Launch at login is not here: `SMAppService` is its source of truth.
public struct KeypadSettings: Codable, Equatable, Sendable {
    public var isEnabled = true
    public var shortcut = Shortcut.default
    public var activeArea = ActiveArea.fullSurface
    public var staysOpenAfterTyping = true
    public var feedback = FeedbackSettings()

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KeypadSettings()
        isEnabled = container.value(Bool.self, for: .isEnabled) ?? defaults.isEnabled
        shortcut = container.value(Shortcut.self, for: .shortcut).flatMap { $0.isValid ? $0 : nil } ?? defaults.shortcut
        activeArea = container.value(ActiveArea.self, for: .activeArea) ?? defaults.activeArea
        staysOpenAfterTyping = container.value(Bool.self, for: .staysOpenAfterTyping) ?? defaults.staysOpenAfterTyping
        feedback = container.value(FeedbackSettings.self, for: .feedback) ?? defaults.feedback
    }

    public var sessionConfiguration: SessionConfiguration {
        var configuration = SessionConfiguration()
        configuration.activeArea = activeArea
        configuration.isSticky = staysOpenAfterTyping
        return configuration
    }
}
