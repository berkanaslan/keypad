import Carbon.HIToolbox
import Foundation
import KeypadCore

@MainActor
public final class KeyboardLayoutDecimalSeparator: DecimalSeparatorProvider {
    public init() {}

    public var decimalSeparator: String {
        KeyboardLayout.character(for: UInt16(kVK_ANSI_KeypadDecimal)) ?? Locale.current.decimalSeparator ?? "."
    }
}
