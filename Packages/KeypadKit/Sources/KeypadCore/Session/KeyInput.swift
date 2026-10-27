/// A physical key pressed during a session, already classified by the system layer.
public enum KeyInput: Equatable, Sendable {
    case digit(Int)
    case decimalSeparator
    case deleteBackward
    case commit(CommitKey)
    case escape
    case other
}
