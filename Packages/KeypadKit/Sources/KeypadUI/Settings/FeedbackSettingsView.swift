import KeypadCore
import SwiftUI

struct FeedbackSettingsView: View {
    let model: SettingsModel

    private var feedback: FeedbackSettings { model.settings.feedback }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { feedback.hapticsOn }, set: { model.setHapticsOn($0) })) {
                    Text("settings.haptics", bundle: .keypadUI)
                }
                Picker(selection: Binding(get: { feedback.hapticPattern }, set: { model.setHapticPattern($0) })) {
                    ForEach(HapticPattern.allCases, id: \.self) { pattern in
                        label(for: pattern).tag(pattern)
                    }
                } label: {
                    Text("settings.haptics.pattern", bundle: .keypadUI)
                }
                .disabled(!feedback.hapticsOn)
            } footer: {
                Text("settings.haptics.footer", bundle: .keypadUI)
            }
            Section {
                Toggle(isOn: Binding(get: { feedback.soundOn }, set: { model.setSoundOn($0) })) {
                    Text("settings.sound", bundle: .keypadUI)
                }
                Picker(selection: Binding(get: { feedback.sound }, set: { model.setSound($0) })) {
                    ForEach(KeySound.allCases, id: \.self) { sound in
                        label(for: sound).tag(sound)
                    }
                } label: {
                    Text("settings.sound.choice", bundle: .keypadUI)
                }
                .disabled(!feedback.soundOn)
            }
        }
        .formStyle(.grouped)
        .frame(width: SettingsMetrics.width)
    }

    private func label(for pattern: HapticPattern) -> Text {
        switch pattern {
        case .standard: Text("haptic.standard", bundle: .keypadUI)
        case .light: Text("haptic.light", bundle: .keypadUI)
        case .pronounced: Text("haptic.pronounced", bundle: .keypadUI)
        }
    }

    private func label(for sound: KeySound) -> Text {
        switch sound {
        case .wood: Text("sound.wood", bundle: .keypadUI)
        case .soft: Text("sound.soft", bundle: .keypadUI)
        case .deep: Text("sound.deep", bundle: .keypadUI)
        case .crisp: Text("sound.crisp", bundle: .keypadUI)
        }
    }
}
