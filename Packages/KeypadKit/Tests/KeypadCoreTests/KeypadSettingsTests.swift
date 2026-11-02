import Foundation
import Testing

@testable import KeypadCore

@Suite struct KeypadSettingsTests {
    @Test func defaultsMatchTheRFC() {
        let settings = KeypadSettings()
        #expect(settings.isEnabled && settings.staysOpenAfterTyping)
        #expect(settings.shortcut == .default && settings.activeArea == .fullSurface)
        #expect(settings.feedback.hapticsOn && settings.feedback.hapticPattern == .standard)
        #expect(settings.feedback.soundOn && settings.feedback.sound == .wood)
    }

    @Test func codableRoundTrip() throws {
        var settings = KeypadSettings()
        settings.isEnabled = false
        settings.feedback.sound = .crisp
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KeypadSettings.self, from: data) == settings)
    }

    @Test func missingFieldsKeepTheirDefaults() throws {
        let decoded = try JSONDecoder().decode(KeypadSettings.self, from: Data(#"{"isEnabled":false}"#.utf8))
        var expected = KeypadSettings()
        expected.isEnabled = false
        #expect(decoded == expected)
    }

    @Test func invalidFieldsFallBackOneByOne() throws {
        let json = """
            {"isEnabled":"yes","staysOpenAfterTyping":false,"feedback":{"sound":"bell","hapticPattern":"light"},\
            "shortcut":{"keyCode":40,"modifiers":0}}
            """
        let decoded = try JSONDecoder().decode(KeypadSettings.self, from: Data(json.utf8))
        #expect(decoded.isEnabled && !decoded.staysOpenAfterTyping)
        #expect(decoded.feedback.sound == .wood && decoded.feedback.hapticPattern == .light)
        #expect(decoded.shortcut == .default)
    }

    @Test func sessionConfigurationFollowsTheSettings() {
        var settings = KeypadSettings()
        settings.staysOpenAfterTyping = false
        settings.activeArea = ActiveArea(x: 0.5, y: 0, width: 0.5, height: 1)
        #expect(!settings.sessionConfiguration.isSticky)
        #expect(settings.sessionConfiguration.activeArea == settings.activeArea)
        #expect(settings.sessionConfiguration.layout == .numpad)
    }

    @Test func feedbackOutputFollowsTheSwitches() {
        var feedback = FeedbackSettings()
        feedback.hapticPattern = .pronounced
        #expect(feedback.output(for: .touchDown) == .haptic(.pronounced))
        #expect(feedback.output(for: .keyAccepted) == .sound(.wood))
        feedback.hapticsOn = false
        feedback.soundOn = false
        #expect(feedback.output(for: .touchDown) == nil && feedback.output(for: .keyAccepted) == nil)
    }
}
