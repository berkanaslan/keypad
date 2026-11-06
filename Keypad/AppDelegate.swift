import AppKit
import KeypadCore
import KeypadSystem
import KeypadUI
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkey: CarbonHotkey
    private let permission = PostEventPermission()
    private let keyboard: KeyboardMonitor
    private let surface: HUDCaptureSurface
    private let feedback: SystemFeedbackPlayer
    private let notices = NoticePanelController { notice in
        NSHostingView(rootView: NoticeView(notice: notice))
    }
    private let runner: SessionRunner
    private let recovery: PermissionRecovery
    private let settings: SettingsModel
    private lazy var settingsWindow = SettingsWindowController(model: settings)

    override init() {
        let decimalSeparator = KeyboardLayoutDecimalSeparator()
        let surface = HUDCaptureSurface(decimalSeparator: decimalSeparator)
        let store = UserDefaultsSettingsStore()
        let saved = store.load()
        let hotkey = CarbonHotkey()
        let feedback = SystemFeedbackPlayer(settings: saved.feedback)
        keyboard = KeyboardMonitor(decimalSeparator: decimalSeparator)
        self.surface = surface
        self.hotkey = hotkey
        self.feedback = feedback
        runner = SessionRunner(
            configuration: saved.sessionConfiguration,
            surface: surface,
            focus: WorkspaceFocusController(),
            keystrokes: CGEventKeystrokeSender(),
            feedback: feedback,
            notices: notices,
            permission: permission,
            secureInput: CarbonSecureInputChecker()
        )
        recovery = PermissionRecovery(permission: permission, watcher: TimerPermissionWatcher(), notices: notices)
        settings = SettingsModel(
            store: store,
            hotkey: hotkey,
            loginItem: LoginItem(),
            feedback: feedback,
            shortcutNames: KeyboardLayoutShortcutNames()
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !permission.canPostEvents {
            permission.requestPostEventAccess()
        }
        recovery.watchIfMissing()
        runner.onPermissionMissing = { [weak recovery] in recovery?.watchIfMissing() }
        hotkey.onPress = { [weak runner] in runner?.shortcutPressed() }
        surface.onTouch = { [weak runner] sample in runner?.receive(sample) }
        surface.onOpenSettings = { [weak runner] in runner?.openPermissionSettings() }
        keyboard.start { [weak runner] key in runner?.receive(key) ?? false }
        settings.onChange = { [weak self] changed in self?.apply(changed) }
        settings.start()
        apply(settings.settings)
    }

    func applicationWillTerminate(_ notification: Notification) {
        surface.hide()
        keyboard.stop()
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        DockMenu.make(
            isEnabled: settings.settings.isEnabled,
            toggle: { [weak self] in
                guard let self else { return }
                settings.setEnabled(!settings.settings.isEnabled)
            },
            openSettings: { [weak self] in self?.showSettings() }
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        settingsWindow.show()
    }

    private func apply(_ changed: KeypadSettings) {
        runner.update(configuration: changed.sessionConfiguration)
        feedback.settings = changed.feedback
        DockIcon.show(isEnabled: changed.isEnabled)
    }
}
