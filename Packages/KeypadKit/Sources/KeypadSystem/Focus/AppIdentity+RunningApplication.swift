import AppKit
import KeypadCore

extension AppIdentity {
    public init(_ app: NSRunningApplication) {
        self.init(
            processID: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? ""
        )
    }
}
