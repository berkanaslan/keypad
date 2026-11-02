import AppKit
import KeypadCore

@MainActor
public final class SystemFeedbackPlayer: FeedbackPlayer, FeedbackPreview {
    public var settings: FeedbackSettings

    /// Loaded once, so the first tap of a session plays without delay.
    private let sounds: [KeySound: NSSound]

    public init(settings: FeedbackSettings) {
        self.settings = settings
        var sounds: [KeySound: NSSound] = [:]
        for sound in KeySound.allCases {
            sounds[sound] = Self.soundURL(for: sound).flatMap { NSSound(contentsOf: $0, byReference: false) }
        }
        self.sounds = sounds
    }

    public func play(_ event: FeedbackEvent) {
        switch settings.output(for: event) {
        case .haptic(let pattern): preview(pattern)
        case .sound(let sound): preview(sound)
        case nil: break
        }
    }

    public func preview(_ pattern: HapticPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(Self.systemPattern(for: pattern), performanceTime: .now)
    }

    public func preview(_ sound: KeySound) {
        guard let player = sounds[sound] else { return }
        player.stop()
        player.play()
    }

    nonisolated static func systemPattern(for pattern: HapticPattern) -> NSHapticFeedbackManager.FeedbackPattern {
        switch pattern {
        case .standard: .generic
        case .light: .alignment
        case .pronounced: .levelChange
        }
    }

    nonisolated static func soundURL(for sound: KeySound) -> URL? {
        Bundle.module.url(forResource: sound.rawValue, withExtension: "wav")
    }
}
