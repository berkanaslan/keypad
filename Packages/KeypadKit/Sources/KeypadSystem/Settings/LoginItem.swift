import KeypadCore
import ServiceManagement

@MainActor
public final class LoginItem: LoginItemController {
    public init() {}

    public var status: LoginItemStatus {
        Self.status(for: SMAppService.mainApp.status)
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    nonisolated static func status(for status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: .on
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }
}
