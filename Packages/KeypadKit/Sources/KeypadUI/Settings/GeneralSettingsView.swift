import KeypadCore
import SwiftUI

struct GeneralSettingsView: View {
    let model: SettingsModel

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { model.settings.isEnabled }, set: { model.setEnabled($0) })) {
                    Text("settings.enabled", bundle: .keypadUI)
                }
            } footer: {
                Text("settings.enabled.footer", bundle: .keypadUI)
            }
            Section {
                Toggle(
                    isOn: Binding(get: { model.loginItemStatus != .off }, set: { model.setOpenAtLogin($0) })
                ) {
                    Text("settings.openAtLogin", bundle: .keypadUI)
                }
                if model.loginItemStatus == .requiresApproval {
                    Text("settings.openAtLogin.approval", bundle: .keypadUI)
                        .foregroundStyle(.secondary)
                    Button {
                        model.openLoginItems()
                    } label: {
                        Text("settings.openAtLogin.openLoginItems", bundle: .keypadUI)
                    }
                }
            }
            Section {
                LabeledContent {
                    HStack {
                        ShortcutRecorderView(model: model)
                        Button {
                            model.resetShortcut()
                        } label: {
                            Text("settings.shortcut.reset", bundle: .keypadUI)
                        }
                    }
                } label: {
                    Text("settings.shortcut", bundle: .keypadUI)
                }
                if model.recorder == .invalid {
                    Text("settings.shortcut.invalid", bundle: .keypadUI)
                        .foregroundStyle(.secondary)
                }
                if model.recorder == .refused || model.isSavedShortcutRefused {
                    Text("settings.shortcut.refused", bundle: .keypadUI)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width)
    }
}
