import Carbon.HIToolbox
import Foundation
import KeypadCore

@MainActor
public final class KeyboardLayoutDecimalSeparator: DecimalSeparatorProvider {
    public init() {}

    public var decimalSeparator: String {
        if let separator = Self.keypadDecimalCharacter(), !separator.isEmpty { return separator }
        return Locale.current.decimalSeparator ?? "."
    }

    private static func keypadDecimalCharacter() -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            var deadKeys: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, UInt16(kVK_ANSI_KeypadDecimal), UInt16(kUCKeyActionDown), 0, UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
            return status == noErr ? String(utf16CodeUnits: characters, count: length) : nil
        }
    }
}
