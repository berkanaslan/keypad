/// Notices a grant made in System Settings. `PermissionChecker` must give a live answer for this to work (RFC-0000 F18).
@MainActor
public final class PermissionRecovery {
    private let permission: PermissionChecker
    private let watcher: PermissionWatcher
    private let notices: NoticeSurface
    private var isWatching = false

    public init(permission: PermissionChecker, watcher: PermissionWatcher, notices: NoticeSurface) {
        self.permission = permission
        self.watcher = watcher
        self.notices = notices
    }

    /// Starts watching when the permission is missing; does nothing while already watching.
    public func watchIfMissing() {
        guard !isWatching, !permission.canPostEvents else { return }
        isWatching = true
        watcher.start { [weak self] in self?.checkForGrant() }
    }

    private func checkForGrant() {
        guard isWatching, permission.canPostEvents else { return }
        isWatching = false
        watcher.stop()
        notices.show(.permissionGranted)
    }
}
