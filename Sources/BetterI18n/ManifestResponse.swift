import Foundation

/// CDN manifest.json yanıtı — JS SDK'daki ManifestResponse ile birebir eşleşir.
/// Tüm field'lar optional yapıldı (gerçek CDN'den eksik field gelebilir),
/// yalnızca `languages` zorunludur.
public struct ManifestResponse: Codable, Sendable {
    public let projectSlug: String?
    public let sourceLanguage: String?

    /// Projede tanımlı tüm diller. Tek zorunlu field.
    public let languages: [ManifestLanguage]

    /// Locale kodu → CDN dosya metadata eşlemesi.
    /// files["tr"].url → direkt CDN URL, biz URL inşa ETMİYORUZ.
    public let files: [String: ManifestFile]?

    public let updatedAt: String?
}

/// Manifest içindeki tek bir dil kaydı.
public struct ManifestLanguage: Codable, Sendable {
    /// Dil kodu — CDN'den zaten lowercase gelir: "tr", "en", "ar"
    public let code: String

    /// İngilizce dil adı: "Turkish", "English"
    public let name: String

    /// Yerel dil adı: "Türkçe", "English"
    public let nativeName: String?

    /// Bu dilin kaynak dil olup olmadığı
    public let isSource: Bool?

    public let lastUpdated: String?
    public let keyCount: Int?

    /// Bayrak görseli URL'i (opsiyonel)
    public let flagUrl: String?

    /// Ülke kodu — dil kodundan FARKLI olabilir.
    /// Örn: "en" dili → "gb" ülke kodu (İngiltere bayrağı).
    public let countryCode: String?
}

/// Manifest files map'indeki dosya metadata kaydı.
public struct ManifestFile: Codable, Sendable {
    /// Pre-built CDN URL — direkt kullanılır, URL inşa gerekmez.
    public let url: String
    public let size: Int?
    public let lastModified: String?
}

/// Public API için sadeleştirilmiş dil seçeneği.
/// SwiftUI listelerinde Identifiable kullanım kolaylığı sağlar.
public struct LanguageOption: Codable, Identifiable, Sendable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let nativeName: String?
    public let flagUrl: String?
    public let isSource: Bool?

    public init(
        code: String,
        name: String,
        nativeName: String? = nil,
        flagUrl: String? = nil,
        isSource: Bool? = nil
    ) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.flagUrl = flagUrl
        self.isSource = isSource
    }
}
