import Foundation
import Testing

@testable import KeypadUI

@Test func shipsEnglishAndTurkish() {
    #expect(Set(Bundle.keypadUI.localizations).isSuperset(of: ["en", "tr"]))
}

@Test(arguments: [
    ("hud.hint", "Yazmak için Return, Tab veya oklar · Kapatmak için Esc"),
    ("hud.permissionMissing", "Keypad'in yazabilmesi için Erişilebilirlik izni gerekiyor"),
    ("hud.permission.openSettings", "Sistem Ayarları'nı Aç"),
    ("hud.backspace.accessibilityLabel", "Sil"),
    ("hud.target.accessibilityLabel", "%@ uygulamasına yazılıyor"),
    ("notice.secureInput", "Güvenli giriş açıkken Keypad yazamaz, örneğin bir şifre alanında"),
    ("notice.permissionGranted", "Keypad artık diğer uygulamalara yazabilir"),
    ("settings.window.title", "Keypad Ayarları"),
    ("settings.open", "Ayarlar…"),
    ("settings.tab.general", "Genel"),
    ("settings.tab.keypad", "Tuş Takımı"),
    ("settings.tab.feedback", "Geri Bildirim"),
    ("settings.enabled", "Keypad'i etkinleştir"),
    ("settings.enabled.footer", "Keypad devre dışıyken kısayolu hiçbir şey yapmaz."),
    ("settings.openAtLogin", "Girişte aç"),
    ("settings.openAtLogin.approval", "Sistem Ayarları'ndaki Giriş Öğeleri'nde Keypad'e izin verin."),
    ("settings.openAtLogin.openLoginItems", "Giriş Öğeleri'ni Aç…"),
    ("settings.shortcut", "Kısayol"),
    ("settings.shortcut.recording", "Bir kısayol yazın…"),
    (
        "settings.shortcut.invalid",
        "Bir tuşla birlikte, biri ⌘ veya ⌃ olan iki değiştirici tuş ya da bir fonksiyon tuşu kullanın."
    ),
    ("settings.shortcut.refused", "macOS bu kısayolu kabul etmedi. Başka bir kısayol deneyin."),
    ("settings.shortcut.reset", "Sıfırla"),
    ("settings.activeArea", "Etkin alan"),
    (
        "settings.activeArea.footer",
        "Alanı veya köşelerini sürükleyin. Parmaklarınızın nereye denk geldiğini görmek için trackpad'e dokunun."
    ),
    ("settings.activeArea.reset", "Tüm Trackpad'i Kullan"),
    (
        "settings.activeArea.accessibilityValue",
        "Genişlik %%%1$lld, yükseklik %%%2$lld, soldan %%%3$lld, alttan %%%4$lld"
    ),
    ("settings.staysOpen", "Yazdıktan sonra açık kal"),
    (
        "settings.staysOpen.footer",
        "Return, Tab ve oklar sayıyı yazar ve tuş takımını bir sonraki sayı için açık tutar."
    ),
    ("settings.haptics", "Dokunsal geri bildirim"),
    ("settings.haptics.pattern", "Desen"),
    ("settings.haptics.footer", "Bir tuşa dokunduğunuzda hissedilir. Force Touch trackpad gerektirir."),
    ("haptic.standard", "Standart"),
    ("haptic.light", "Hafif"),
    ("haptic.pronounced", "Belirgin"),
    ("settings.sound", "Tuş sesi"),
    ("settings.sound.choice", "Ses"),
    ("sound.wood", "Ahşap"),
    ("sound.soft", "Yumuşak"),
    ("sound.deep", "Derin"),
    ("sound.crisp", "İnce"),
    ("dock.disable", "Keypad'i Devre Dışı Bırak"),
    ("dock.enable", "Keypad'i Etkinleştir"),
])
func stringsAreTranslatedToTurkish(key: String, turkish: String) throws {
    let path = try #require(Bundle.keypadUI.path(forResource: "tr", ofType: "lproj"))
    let bundle = try #require(Bundle(path: path))
    #expect(bundle.localizedString(forKey: key, value: nil, table: nil) == turkish)
}
