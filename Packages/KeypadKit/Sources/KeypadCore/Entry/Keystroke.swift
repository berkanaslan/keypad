public enum ArrowDirection: Equatable, Sendable {
    case left, right, up, down
}

public enum CommitKey: Equatable, Sendable {
    case returnKey
    case shiftReturn
    case keypadEnter
    case tab
    case shiftTab
    case arrow(ArrowDirection)
}

/// A key press to deliver to the focused app, independent of how the system layer posts it.
public enum Keystroke: Equatable, Sendable {
    case keypadDigit(Int)
    case keypadDecimal
    case commit(CommitKey)
}
