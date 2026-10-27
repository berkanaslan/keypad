import AppKit
import KeypadCore
import KeypadSystem
import KeypadUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkey = CarbonHotkey()
    private let permission = PostEventPermission()
    private let keyboard: KeyboardMonitor
    private let surface: HUDCaptureSurface
    private let notices = NoticePanelController { notice in
        NSHostingView(rootView: NoticeView(notice: notice))
    }
    private let runner: SessionRunner

    override init() {
        let decimalSeparator = KeyboardLayoutDecimalSeparator()
        let surface = HUDCaptureSurface(decimalSeparator: decimalSeparator)
        keyboard = KeyboardMonitor(decimalSeparator: decimalSeparator)
        self.surface = surface
        runner = SessionRunner(
            configuration: SessionConfiguration(),
            surface: surface,
            focus: WorkspaceFocusController(),
            keystrokes: CGEventKeystrokeSender(),
            feedback: SystemFeedbackPlayer(),
            notices: notices,
            permission: permission,
            secureInput: CarbonSecureInputChecker()
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !permission.canPostEvents {
            permission.requestPostEventAccess()
        }
        hotkey.onPress = { [weak runner] in runner?.shortcutPressed() }
        surface.onTouch = { [weak runner] sample in runner?.receive(sample) }
        keyboard.start { [weak runner] key in runner?.receive(key) ?? false }
        hotkey.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        surface.hide()
        keyboard.stop()
    }
}
