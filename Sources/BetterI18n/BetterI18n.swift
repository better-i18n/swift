import Foundation

/// better-i18n Swift SDK'sının ana sınıfı.
///
/// JS SDK'daki `createI18nCore()` + `BetterI18n` sınıfını mirror eder.
///
/// Fetch stratejisi (offline-first, JS SDK ile aynı):
/// 1. TtlCache (bellek) — en hızlı, process içi
/// 2. CDN fetch — URLSession, exponential backoff
/// 3. Persistent storage — UserDefaults / AppGroupStorage (JSON string)
/// 4. throw — tümü başarısız olursa
///
/// ```swift
/// let i18n = BetterI18n(config: I18nConfig(
///     project: "hellospace/safa",
///     defaultLocale: "tr"
/// ))
/// let t = try await i18n.getTranslator("tr")
/// print(t("auth.landing.title"))
/// ```
public final class BetterI18n: @unchecked Sendable {
    let config: I18nConfig

    private let cdnClient: CDNClient
    private let manifestCache: TtlCache<ManifestResponse>
    private let messagesCache: TtlCache<[String: Any]>
    private let storage: any TranslationStorage

    // MARK: - Init

    public init(config: I18nConfig) {
        self.config = config
        self.cdnClient = CDNClient(config: config)
        self.manifestCache = TtlCache()
        self.messagesCache = TtlCache()

        // Storage önceliği: explicit > appGroup > standart UserDefaults
        if let explicit = config.storage {
            self.storage = explicit
        } else if let appGroup = config.appGroupIdentifier {
            self.storage = AppGroupStorage(suiteName: appGroup)
        } else {
            self.storage = UserDefaultsStorage()
        }
    }

    /// Test için: özel URLSession inject et (URLProtocol mock'u için)
    init(config: I18nConfig, session: URLSession) {
        self.config = config
        self.cdnClient = CDNClient(config: config, session: session)
        self.manifestCache = TtlCache()
        self.messagesCache = TtlCache()
        self.storage = config.storage ?? UserDefaultsStorage()
    }

    // MARK: - Public API

    /// Proje default locale'ini döner.
    public var defaultLocale: String { config.defaultLocale }

    /// Manifest'i döner. TtlCache → CDN → storage fallback zinciri.
    /// - Parameter forceRefresh: `true` ise bellek cache atlanır.
    public func getManifest(forceRefresh: Bool = false) async throws -> ManifestResponse {
        let cacheKey = "\(config.cdnBaseUrl)|\(config.project)"

        if !forceRefresh, let cached = await manifestCache.get(cacheKey) {
            debugLog("Manifest cache'den döndü.")
            return cached
        }

        do {
            let manifest = try await cdnClient.fetchManifest()
            await manifestCache.set(cacheKey, value: manifest, ttlMs: config.manifestCacheTtlMs)
            await persistManifest(manifest)
            debugLog("Manifest CDN'den çekildi: \(manifest.languages.count) dil.")
            return manifest
        } catch {
            debugLog("CDN hatası, storage fallback deneniyor: \(error)")
            if let manifest = await loadManifestFromStorage() {
                return manifest
            }
            throw error
        }
    }

    /// Verilen locale için çeviri mesajlarını döner (nested [String: Any]).
    public func getMessages(locale: String) async throws -> [String: Any] {
        let cacheKey = "\(config.cdnBaseUrl)|\(config.project)|\(locale)"

        if let cached = await messagesCache.get(cacheKey) {
            debugLog("Messages cache'den döndü: \(locale)")
            return cached
        }

        let manifest = try await getManifest()
        let urlString = manifest.files?[locale]?.url
            ?? "\(config.cdnBaseUrl)/\(config.project)/\(locale)/translations.json"

        do {
            let messages = try await cdnClient.fetchTranslations(url: urlString)
            await messagesCache.set(cacheKey, value: messages, ttlMs: config.manifestCacheTtlMs)
            await persistMessages(messages, locale: locale)
            debugLog("Messages CDN'den çekildi: \(locale)")
            return messages
        } catch {
            debugLog("CDN hatası, storage fallback: \(error)")
            if let messages = await loadMessagesFromStorage(locale: locale) {
                return messages
            }
            throw error
        }
    }

    /// Verilen locale için `Translator` döner. t("key") çağrısına hazır.
    public func getTranslator(locale: String) async throws -> Translator {
        let messages = try await getMessages(locale: locale)
        return Translator(messages: messages, locale: locale)
    }

    /// Projede mevcut tüm locale kodlarını döner: ["tr", "en", "ar", ...]
    public func getLocales() async throws -> [String] {
        let manifest = try await getManifest()
        return manifest.languages.map { $0.code }
    }

    /// Projede mevcut dilleri `LanguageOption` listesi olarak döner (SwiftUI için).
    public func getLanguages() async throws -> [LanguageOption] {
        let manifest = try await getManifest()
        return manifest.languages.map { lang in
            LanguageOption(
                code: lang.code,
                name: lang.name,
                nativeName: lang.nativeName,
                flagUrl: lang.flagUrl,
                isSource: lang.isSource
            )
        }
    }

    /// Cihaz tercihine göre en uygun locale'i tespit eder.
    ///
    /// Öncelik sırası:
    /// 1. Storage'daki kaydedilmiş kullanıcı tercihi
    /// 2. `bestMatchLocale(Locale.preferredLanguages, against: manifestCodes)`
    /// 3. `config.defaultLocale`
    public func detectLocale() async throws -> String {
        let prefKey = "@better-i18n:locale:\(config.project)"
        if let saved = await storage.get(prefKey), !saved.isEmpty {
            debugLog("Kaydedilmiş locale bulundu: \(saved)")
            return saved
        }

        let manifest = try await getManifest()
        let codes = manifest.languages.map { $0.code }
        let deviceLocales = Locale.preferredLanguages

        if let matched = LocaleDetector.bestMatchLocale(deviceLocales, against: codes) {
            debugLog("Cihaz locale eşleşti: \(matched)")
            return matched
        }

        debugLog("Eşleşme bulunamadı, defaultLocale kullanılıyor: \(config.defaultLocale)")
        return config.defaultLocale
    }

    /// Kullanıcı dil tercihini kaydeder. Bir sonraki `detectLocale()` bunu döner.
    public func saveLocalePreference(_ locale: String) async {
        let prefKey = "@better-i18n:locale:\(config.project)"
        await storage.set(prefKey, value: locale)
    }

    // MARK: - Private Helpers

    private func persistManifest(_ manifest: ManifestResponse) async {
        guard let data = try? JSONEncoder().encode(manifest),
              let json = String(data: data, encoding: .utf8) else { return }
        let key = "@better-i18n:manifest:\(config.project)"
        await storage.set(key, value: json)
    }

    private func loadManifestFromStorage() async -> ManifestResponse? {
        let key = "@better-i18n:manifest:\(config.project)"
        guard let json = await storage.get(key),
              let data = json.data(using: .utf8),
              let manifest = try? JSONDecoder().decode(ManifestResponse.self, from: data)
        else { return nil }
        return manifest
    }

    private func persistMessages(_ messages: [String: Any], locale: String) async {
        guard let data = try? JSONSerialization.data(withJSONObject: messages),
              let json = String(data: data, encoding: .utf8) else { return }
        let key = "@better-i18n:messages:\(config.project):\(locale)"
        await storage.set(key, value: json)
    }

    private func loadMessagesFromStorage(locale: String) async -> [String: Any]? {
        let key = "@better-i18n:messages:\(config.project):\(locale)"
        guard let json = await storage.get(key),
              let data = json.data(using: .utf8),
              let messages = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return messages
    }

    private func debugLog(_ message: String) {
        if config.debug {
            print("[BetterI18n] \(message)")
        }
    }
}
