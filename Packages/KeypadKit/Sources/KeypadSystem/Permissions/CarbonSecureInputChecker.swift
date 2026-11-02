import Carbon
import KeypadCore

@MainActor
public final class CarbonSecureInputChecker: SecureInputChecker {
    public init() {}

    public var isSecureInputOn: Bool {
        IsSecureEventInputEnabled()
    }
}
