import SwiftUI
import BetterI18n

/// `I18nStore`'a `EnvironmentValues` üzerinden doğrudan erişim sağlar.
///
/// `.environmentObject` yerine alternatif bir erişim yolu.
/// `I18nProvider` kullanılıyorsa genellikle `@EnvironmentObject` tercih edilir.
///
/// ```swift
/// // View içinde:
/// @Environment(\.i18n) private var i18n: I18nStore?
///
/// // Body içinde:
/// if let i18n {
///     Text(i18n.t("home.title"))
/// }
/// ```
public struct I18nEnvironmentKey: EnvironmentKey {
    public static let defaultValue: I18nStore? = nil
}

public extension EnvironmentValues {
    var i18n: I18nStore? {
        get { self[I18nEnvironmentKey.self] }
        set { self[I18nEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// `I18nStore`'u environment'a ekler.
    ///
    /// ```swift
    /// ContentView()
    ///     .i18nStore(store)
    /// ```
    func i18nStore(_ store: I18nStore) -> some View {
        environment(\.i18n, store)
    }
}
