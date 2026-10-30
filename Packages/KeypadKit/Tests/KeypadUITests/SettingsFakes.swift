import KeypadCore

@testable import KeypadUI

@MainActor
final class FakeStore: SettingsStore {
    var stored: KeypadSettings
    private(set) var saved: [KeypadSettings] = []

    init(stored: KeypadSettings) { self.stored = stored }

    func load() -> KeypadSettings { stored }
    func save(_ settings: KeypadSettings) { saved.append(settings) }
}

@MainActor
final class FakeRegistrar: HotkeyRegistrar {
    var results: [Bool]
    private(set) var registered: Shortcut?

    init(results: [Bool]) { self.results = results }

    func register(_ shortcut: Shortcut) -> Bool {
        let accepted = results.isEmpty ? true : results.removeFirst()
        registered = accepted ? shortcut : nil
        return accepted
    }

    func unregister() { registered = nil }
}

struct LoginItemFailure: Error {}

@MainActor
final class FakeLoginItem: LoginItemController {
    var status = LoginItemStatus.off
    var shouldThrow = false

    func setEnabled(_ enabled: Bool) throws {
        if shouldThrow { throw LoginItemFailure() }
        status = enabled ? .on : .off
    }

    func openSystemSettings() {}
}

@MainActor
final class FakePreview: FeedbackPreview {
    private(set) var previews: [String] = []

    func preview(_ pattern: HapticPattern) { previews.append(pattern.rawValue) }
    func preview(_ sound: KeySound) { previews.append(sound.rawValue) }
}

@MainActor
struct FakeNames: ShortcutNaming {
    func name(for shortcut: Shortcut) -> String { "name" }
}

@MainActor
struct Harness {
    let store: FakeStore
    let registrar: FakeRegistrar
    let loginItem = FakeLoginItem()
    let preview = FakePreview()
    let model: SettingsModel

    init(saved: KeypadSettings = KeypadSettings(), registerResults: [Bool] = []) {
        store = FakeStore(stored: saved)
        registrar = FakeRegistrar(results: registerResults)
        model = SettingsModel(
            store: store, hotkey: registrar, loginItem: loginItem, feedback: preview, shortcutNames: FakeNames())
    }
}
