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
    /// Manuel kullanımda `task { await store.load() }` ile tetiklenebilir.
    public func load() async {
        do {
            locale = try await core.detectLocale()
            languages = try await core.getLanguages()
            translator = try await core.getTranslator(locale: locale)
            isLoaded = true
            error = nil
        } catch {
            self.error = error
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
