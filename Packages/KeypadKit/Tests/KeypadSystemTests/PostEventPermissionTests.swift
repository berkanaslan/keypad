import Testing

@testable import KeypadSystem

@MainActor @Test func settingsLinkOpensAccessibility() {
    #expect(
        PostEventPermission.settingsLink.absoluteString
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )
}
