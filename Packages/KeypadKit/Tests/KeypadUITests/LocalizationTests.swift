import Foundation
import Testing

@testable import KeypadUI

@Test func shipsEnglishAndTurkish() {
    #expect(Set(Bundle.keypadUI.localizations).isSuperset(of: ["en", "tr"]))
}

@Test func placeholderIsTranslatedToTurkish() throws {
    let path = try #require(Bundle.keypadUI.path(forResource: "tr", ofType: "lproj"))
    let turkish = try #require(Bundle(path: path))
    #expect(
        turkish.localizedString(forKey: "settings.placeholder", value: nil, table: nil) == "Ayarlar burada görünecek.")
}
