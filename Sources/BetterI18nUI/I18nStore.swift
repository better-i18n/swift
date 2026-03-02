import Foundation
import SwiftUI
import BetterI18n

/// SwiftUI uygulamaları için reactive i18n state yöneticisi.
///
/// `@ObservableObject` olduğu için `@EnvironmentObject` veya `@StateObject` ile
/// tüm view tree'ye dağıtılabilir. `@MainActor` ile tüm `@Published` güncellemeleri
/// main thread'de gerçekleşir — UI güncellemeleri için ekstra `DispatchQueue.main` gerekmez.
///
/// ```swift
/// @EnvironmentObject var i18n: I18nStore
///
/// Text(i18n.t("home.title"))
/// Text(i18n.t("welcome.message", ["name": "Osman"]))
/// ```
@MainActor
public final class I18nStore: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var locale: String
    @Published public private(set) var languages: [LanguageOption] = []
    @Published public private(set) var isLoaded: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var error: Error? = nil

    // MARK: - Private

    private let core: BetterI18n
    private var translator: Translator?

    // MARK: - Init

    public init(core: BetterI18n) {
        self.core = core
        self.locale = core.defaultLocale
    }

    // MARK: - Load

    /// Manifest ve çevirileri yükler. `I18nProvider` bunu otomatik çağırır.
    /// Manuel kullanımda `.task { await store.load() }` ile tetiklenebilir.
    ///
    /// **İki fazlı strateji (offline-first):**
    /// - Phase 1: TtlCache / storage → anlık, CDN çağrısı yok. `isLoaded=true`.
    /// - Phase 2: CDN refresh → taze veri gelince UI güncellenir. `isRefreshing=false`.
    ///
    /// Phase 1 başarılıysa Phase 2 hatası kullanıcıya gösterilmez — stale veri korunur.
    public func load() async {
        // PHASE 1 — Storage / TtlCache: CDN çağrısı yok, anında döner
        let storedLocale = await core.detectLocaleFromStorageOnly()
        let storedManifest = await core.getManifestFromStorageOnly()
        let storedTranslator = await core.getTranslatorFromStorageOnly(locale: storedLocale)

        if let manifest = storedManifest, let t = storedTranslator {
            locale = storedLocale
            languages = manifest.languages.map { lang in
                LanguageOption(
                    code: lang.code,
                    name: lang.name,
                    nativeName: lang.nativeName,
                    flagUrl: lang.flagUrl,
                    isSource: lang.isSource
                )
            }
            translator = t
            isLoaded = true
            // SwiftUI bu await'ten sonra re-render eder — stale veri görünür,
            // Phase 2 arka planda devam eder
        }

        // PHASE 2 — CDN refresh (taze veri)
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let freshLocale = try await core.detectLocale()
            let freshLanguages = try await core.getLanguages()
            let freshTranslator = try await core.getTranslator(locale: freshLocale)

            locale = freshLocale
            languages = freshLanguages
            translator = freshTranslator
            isLoaded = true
            error = nil
        } catch {
            // Phase 1 başarılıysa stale veriyi koru, error gösterme
            if !isLoaded {
                self.error = error
            }
        }
    }

    // MARK: - Locale Switch

    /// Kullanıcı locale tercihini değiştirir ve çevirileri yeniden yükler.
    /// Tercihi storage'a kaydeder — bir sonraki açılışta bu locale kullanılır.
    public func setLocale(_ locale: String) async {
        do {
            self.locale = locale
            await core.saveLocalePreference(locale)
            translator = try await core.getTranslator(locale: locale)
            error = nil
        } catch {
            self.error = error
        }
    }

    // MARK: - Translation API

    /// Key için çeviri döner. `callAsFunction` ile aynı davranış.
    ///
    ///     Text(i18n.t("auth.login.title"))
    public func t(_ key: String) -> String {
        translator?(key) ?? key
    }

    /// Değişken ikamesiyle çeviri döner.
    ///
    ///     Text(i18n.t("welcome.message", ["name": "Osman"]))
    public func t(_ key: String, _ variables: [String: String]) -> String {
        translator?(key, variables) ?? key
    }
}
