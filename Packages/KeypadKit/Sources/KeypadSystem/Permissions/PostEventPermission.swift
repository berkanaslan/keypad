import CoreGraphics
import KeypadCore

@MainActor
public final class PostEventPermission: PermissionChecker {
    public init() {}

    public var canPostEvents: Bool {
        CGPreflightPostEventAccess()
    }

    public func requestPostEventAccess() {
        CGRequestPostEventAccess()
    }
}
