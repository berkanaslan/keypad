import AppKit
import ApplicationServices
import CoreGraphics
import KeypadCore

@MainActor
public final class PostEventPermission: PermissionChecker {
    static let settingsLink = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    public init() {}

    /// `CGPreflightPostEventAccess` keeps its first answer for the life of the process (RFC-0000 F18).
    public var canPostEvents: Bool {
        AXIsProcessTrusted()
    }

    public func requestPostEventAccess() {
        CGRequestPostEventAccess()
    }

    public func openPermissionSettings() {
        guard !NSWorkspace.shared.open(Self.settingsLink) else { return }
        NSWorkspace.shared.open(URL(filePath: "/System/Applications/System Settings.app"))
    }
}
