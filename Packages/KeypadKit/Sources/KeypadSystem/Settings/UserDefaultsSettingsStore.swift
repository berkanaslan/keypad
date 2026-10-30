import Foundation
import KeypadCore

/// Keeps every setting in one versioned JSON entry, written atomically.
@MainActor
public final class UserDefaultsSettingsStore: SettingsStore {
    private struct Entry: Codable {
        var version = 1
        var settings: KeypadSettings
    }

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> KeypadSettings {
        guard let data = defaults.data(forKey: key), let entry = try? JSONDecoder().decode(Entry.self, from: data)
        else { return KeypadSettings() }
        return entry.settings
    }

    public func save(_ settings: KeypadSettings) {
        guard let data = try? JSONEncoder().encode(Entry(settings: settings)) else { return }
        defaults.set(data, forKey: key)
    }
}
