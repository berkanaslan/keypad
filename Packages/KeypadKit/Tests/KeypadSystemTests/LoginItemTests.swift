import KeypadCore
import ServiceManagement
import Testing

@testable import KeypadSystem

@Test(arguments: [
    (SMAppService.Status.enabled, LoginItemStatus.on), (.requiresApproval, .requiresApproval),
    (.notRegistered, .off), (.notFound, .off),
])
func loginItemStatusMapsFromServiceManagement(service: SMAppService.Status, expected: LoginItemStatus) {
    #expect(LoginItem.status(for: service) == expected)
}
