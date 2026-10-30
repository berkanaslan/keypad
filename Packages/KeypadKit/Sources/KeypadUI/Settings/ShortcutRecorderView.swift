import AppKit
import KeypadCore
import SwiftUI

/// Records the next key combination as the shortcut. Esc, any click or leaving Keypad cancels.
struct ShortcutRecorderView: View {
    let model: SettingsModel
    @State private var capture = ShortcutCapture()

    private var isRecording: Bool { model.recorder == .recording || model.recorder == .invalid }

    var body: some View {
        Button {
            if isRecording {
                model.cancelRecording()
            } else {
                startRecording()
            }
        } label: {
            Group {
                if isRecording {
                    Text("settings.shortcut.recording", bundle: .keypadUI)
                } else {
                    Text(model.shortcutName)
                }
            }
            .frame(minWidth: 120)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording { capture.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            model.abandonRecording()
        }
        .onDisappear {
            model.abandonRecording()
            capture.stop()
        }
    }

    private func startRecording() {
        model.startRecording()
        capture.start(onKey: { [model] in model.record($0) }, onCancel: { [model] in model.cancelRecording() })
    }
}
