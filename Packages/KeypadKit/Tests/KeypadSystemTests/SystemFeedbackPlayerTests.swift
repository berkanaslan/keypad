import AppKit
import KeypadCore
import Testing

@testable import KeypadSystem

@Test(arguments: [
    (HapticPattern.standard, NSHapticFeedbackManager.FeedbackPattern.generic),
    (.light, .alignment), (.pronounced, .levelChange),
])
func hapticPatternsMapToTheSystem(pattern: HapticPattern, system: NSHapticFeedbackManager.FeedbackPattern) {
    #expect(SystemFeedbackPlayer.systemPattern(for: pattern) == system)
}

// NSSound is AppKit: parallel test cases loading it off the main thread crashed inside AVFAudio.
@MainActor
@Test(arguments: KeySound.allCases)
func everyKeySoundIsBundled(sound: KeySound) throws {
    let url = try #require(SystemFeedbackPlayer.soundURL(for: sound))
    #expect(NSSound(contentsOf: url, byReference: false) != nil)
}
