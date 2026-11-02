/// The app a session types into.
public struct AppIdentity: Equatable, Sendable {
    public let processID: Int32
    public let bundleIdentifier: String?
    public let name: String

    public init(processID: Int32, bundleIdentifier: String?, name: String) {
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.name = name
    }
}
