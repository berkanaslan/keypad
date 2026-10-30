import KeypadUI
import SwiftUI

@main
struct KeypadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// SwiftUI needs a scene; the Settings window itself is AppKit and opens through `SettingsCommands`.
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            SettingsCommands { appDelegate.showSettings() }
        }
    }
}
