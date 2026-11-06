import AppKit
import CoreGraphics
import KeypadCore

@MainActor
public final class PostEventPermission: PermissionChecker {
    static let settingsLink = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    public init() {}

    public var canPostEvents: Bool {
        CGPreflightPostEventAccess()
    }

    public func requestPostEventAccess() {
        CGRequestPostEventAccess()
    }

    public func openPermissionSettings() {
        guard !NSWorkspace.shared.open(Self.settingsLink) else { return }
        NSWorkspace.shared.open(URL(filePath: "/System/Applications/System Settings.app"))
    }
}
