import AppKit
import SwiftUI
import Testing

@testable import KeypadUI

@MainActor
struct NumberDisplayTests {
    private func height(of digits: Int) -> CGFloat {
        let text = String(repeating: "7", count: digits)
        return NSHostingView(rootView: NumberDisplay(text: text).frame(width: 280)).fittingSize.height
    }

    @Test func staysOnOneLineWhileTheScaledDownDigitsFit() {
        #expect(height(of: 12) == height(of: 0))
    }

    @Test func wrapsInsteadOfTruncating() {
        #expect(height(of: 24) > height(of: 12))
        #expect(height(of: 200) > height(of: 24))
    }
}
