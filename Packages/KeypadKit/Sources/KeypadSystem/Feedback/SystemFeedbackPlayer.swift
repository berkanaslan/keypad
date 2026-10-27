import AppKit
import KeypadCore

@MainActor
public final class SystemFeedbackPlayer: FeedbackPlayer {
    private let soundName: String

    public init(soundName: String = "Tink") {
        self.soundName = soundName
    }

    public func play(_ event: FeedbackEvent) {
        switch event {
        case .touchDown:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        case .keyAccepted:
            guard let sound = NSSound(named: NSSound.Name(soundName)) else { return }
            sound.stop()
            sound.play()
        }
    }
}
