public enum HapticPattern: String, Codable, CaseIterable, Sendable {
    case standard, light, pronounced
}

public enum KeySound: String, Codable, CaseIterable, Sendable {
    case wood, soft, deep, crisp
}

public enum FeedbackOutput: Equatable, Sendable {
    case haptic(HapticPattern)
    case sound(KeySound)
}

public struct FeedbackSettings: Codable, Equatable, Sendable {
    public var hapticsOn = true
    public var hapticPattern = HapticPattern.standard
    public var soundOn = true
    public var sound = KeySound.wood

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FeedbackSettings()
        hapticsOn = container.value(Bool.self, for: .hapticsOn) ?? defaults.hapticsOn
        hapticPattern = container.value(HapticPattern.self, for: .hapticPattern) ?? defaults.hapticPattern
        soundOn = container.value(Bool.self, for: .soundOn) ?? defaults.soundOn
        sound = container.value(KeySound.self, for: .sound) ?? defaults.sound
    }

    public func output(for event: FeedbackEvent) -> FeedbackOutput? {
        switch event {
        case .touchDown: hapticsOn ? .haptic(hapticPattern) : nil
        case .keyAccepted: soundOn ? .sound(sound) : nil
        }
    }
}
