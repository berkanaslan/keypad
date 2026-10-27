/// The number being entered. Like a hardware numpad, it accepts whatever is tapped and validates nothing.
public struct EntryBuffer: Equatable, Sendable {
    public private(set) var actions: [KeyAction] = []

    public init() {}

    public var isEmpty: Bool { actions.isEmpty }

    public mutating func apply(_ action: KeyAction) {
        switch action {
        case .digit, .decimalSeparator:
            actions.append(action)
        case .backspace:
            _ = actions.popLast()
        }
    }

    public func display(decimalSeparator: String) -> String {
        actions.compactMap { action in
            switch action {
            case .digit(let value): String(value)
            case .decimalSeparator: decimalSeparator
            case .backspace: nil
            }
        }.joined()
    }

    public var keystrokes: [Keystroke] {
        actions.compactMap { action in
            switch action {
            case .digit(let value): .keypadDigit(value)
            case .decimalSeparator: .keypadDecimal
            case .backspace: nil
            }
        }
    }
}
