import Foundation

/// better-i18n SDK konfigürasyonu.
/// JS SDK'daki I18nConfig ile birebir eşleşen alan isimleri.
public struct I18nConfig: @unchecked Sendable {
    /// "org/project" formatında proje tanımlayıcı (ör. "hellospace/safa")
    public let project: String

    /// Hiçbir locale eşleşmediğinde kullanılacak varsayılan dil kodu (ör. "en", "tr")
    public let defaultLocale: String

    /// CDN base URL'i. Varsayılan: "https://cdn.better-i18n.com"
    public var cdnBaseUrl: String

    /// Manifest cache TTL (millisaniye). Varsayılan: 5 dakika
    public var manifestCacheTtlMs: Double

    /// Özel storage implementasyonu. nil → UserDefaultsStorage kullanılır.
    /// appGroupIdentifier varsa otomatik olarak AppGroupStorage seçilir.
    public var storage: (any TranslationStorage)?

    /// Widget / App Extension paylaşımı için App Group identifier.
    /// "group.com.hellospace.safa" gibi. Varsa AppGroupStorage otomatik seçilir.
    public var appGroupIdentifier: String?

    /// CDN fetch timeout saniyesi. Varsayılan: 10
    public var fetchTimeout: TimeInterval

    /// Başarısız isteğin kaç kez tekrar deneneceği. Varsayılan: 1
    public var retryCount: Int

    /// Debug loglarını etkinleştirir. Varsayılan: false
    public var debug: Bool

    public init(
        project: String,
        defaultLocale: String,
        cdnBaseUrl: String = "https://cdn.better-i18n.com",
        manifestCacheTtlMs: Double = 300_000,
        storage: (any TranslationStorage)? = nil,
        appGroupIdentifier: String? = nil,
        fetchTimeout: TimeInterval = 10,
        retryCount: Int = 1,
        debug: Bool = false
    ) {
        self.project = project
        self.defaultLocale = defaultLocale
        self.cdnBaseUrl = cdnBaseUrl
        self.manifestCacheTtlMs = manifestCacheTtlMs
        self.storage = storage
        self.appGroupIdentifier = appGroupIdentifier
        self.fetchTimeout = fetchTimeout
        self.retryCount = retryCount
        self.debug = debug
    }
}
