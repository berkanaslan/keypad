import KeypadCore
import SwiftUI

struct KeypadSettingsView: View {
    let model: SettingsModel
    let liveTouches: LiveTouches

    var body: some View {
        Form {
            Section {
                ActiveAreaEditor(area: model.settings.activeArea, touches: liveTouches.points) {
                    model.setActiveArea($0)
                }
                Button {
                    model.setActiveArea(.fullSurface)
                } label: {
                    Text("settings.activeArea.reset", bundle: .keypadUI)
                }
            } header: {
                Text("settings.activeArea", bundle: .keypadUI)
            } footer: {
                Text("settings.activeArea.footer", bundle: .keypadUI)
            }
            Section {
                Toggle(
                    isOn: Binding(
                        get: { model.settings.staysOpenAfterTyping }, set: { model.setStaysOpenAfterTyping($0) })
                ) {
                    Text("settings.staysOpen", bundle: .keypadUI)
                }
            } footer: {
                Text("settings.staysOpen.footer", bundle: .keypadUI)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width)
    }
}
