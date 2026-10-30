import Foundation
import KeypadCore
import Testing

@testable import KeypadSystem

@MainActor
@Suite struct UserDefaultsSettingsStoreTests {
    private let suite = "keypad.tests.\(UUID().uuidString)"

    private func makeStore() -> (UserDefaultsSettingsStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: suite)!
        return (UserDefaultsSettingsStore(defaults: defaults), defaults)
    }

    @Test func savedSettingsLoadBack() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        var settings = KeypadSettings()
        settings.feedback.hapticPattern = .light
        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func missingEntryLoadsDefaults() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(store.load() == KeypadSettings())
    }

    @Test func garbageDataLoadsDefaults() {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("not json".utf8), forKey: "settings")
        #expect(store.load() == KeypadSettings())
    }

    @Test func entryCarriesAVersion() throws {
        let (store, defaults) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }
        store.save(KeypadSettings())
        let data = try #require(defaults.data(forKey: "settings"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["version"] as? Int == 1)
    }
}
