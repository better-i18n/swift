import Foundation

/// Cihaz dil tercihlerini CDN manifest locale kodlarıyla eşleştiren yardımcı.
///
/// Apple, `Locale.preferredLanguages`'den BCP 47 formatında kodlar döner:
/// `["tr-TR", "en-US", "de-DE"]`
///
/// CDN'den gelen kodlar zaten lowercase basit kodlardır: `["tr", "en", "de"]`
/// Bu yüzden `normalizeLocale` gerekmez — yalnızca base-language eşleşmesi yeterli.
public enum LocaleDetector {

    /// Cihazın tercih ettiği locale listesini manifest'teki mevcut kodlarla eşleştirir.
    ///
    /// Eşleşme önceliği:
    /// 1. Tam eşleşme: `"tr"` → `"tr"` ✓
    /// 2. Base dil eşleşmesi: `"tr-TR"` → base `"tr"` → manifest'te varsa ✓
    ///
    /// - Parameters:
    ///   - deviceLocales: `Locale.preferredLanguages` listesi (BCP 47 formatı).
    ///   - codes: Manifest'ten gelen mevcut locale kodları (lowercase, 2-harfli).
    /// - Returns: İlk eşleşen kod, yoksa `nil`.
    public static func bestMatchLocale(_ deviceLocales: [String], against codes: [String]) -> String? {
        for deviceLocale in deviceLocales {
            // 1. Tam eşleşme: "tr" → "tr"
            if codes.contains(deviceLocale) {
                return deviceLocale
            }
            // 2. Base dil eşleşmesi: "tr-TR" → "tr"
            let base = deviceLocale.components(separatedBy: "-").first ?? deviceLocale
            if codes.contains(base) {
                return base
            }
        }
        return nil
    }
}
