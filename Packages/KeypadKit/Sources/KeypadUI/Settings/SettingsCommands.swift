import SwiftUI

/// Replaces the app menu's Settings item, so ⌘, opens the AppKit Settings window.
public struct SettingsCommands: Commands {
    private let showSettings: @MainActor () -> Void

    public init(showSettings: @escaping @MainActor () -> Void) {
        self.showSettings = showSettings
    }

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button {
                showSettings()
            } label: {
                Text("settings.open", bundle: .keypadUI)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}
