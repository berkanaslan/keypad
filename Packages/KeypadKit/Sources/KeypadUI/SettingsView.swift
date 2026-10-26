import SwiftUI

public struct SettingsView: View {
    public init() {}

    public var body: some View {
        Text("settings.placeholder", bundle: .keypadUI)
            .padding()
            .frame(minWidth: 420, minHeight: 240)
    }
}
