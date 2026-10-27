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

@Test(arguments: [
    ("hud.hint", "Yazmak için Return, Tab veya oklar · Kapatmak için Esc"),
    ("hud.permissionMissing", "Keypad'in yazabilmesi için Erişilebilirlik izni gerekiyor"),
    ("hud.backspace.accessibilityLabel", "Sil"),
    ("hud.target.accessibilityLabel", "%@ uygulamasına yazılıyor"),
    ("notice.secureInput", "Güvenli giriş açıkken Keypad yazamaz, örneğin bir şifre alanında"),
])
func hudStringsAreTranslatedToTurkish(key: String, turkish: String) throws {
    let path = try #require(Bundle.keypadUI.path(forResource: "tr", ofType: "lproj"))
    let bundle = try #require(Bundle(path: path))
    #expect(bundle.localizedString(forKey: key, value: nil, table: nil) == turkish)
}
