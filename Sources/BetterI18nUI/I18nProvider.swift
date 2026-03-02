import SwiftUI
import BetterI18n

/// `I18nStore`'u tüm child view'lara `.environmentObject` ile enjekte eden wrapper.
///
/// Uygulama başlangıcında tek sefer kullanılır:
///
/// ```swift
/// @main struct MyApp: App {
///     let i18n = BetterI18n(config: I18nConfig(
///         project: "my-org/my-app",
///         defaultLocale: "en"
///     ))
///
///     var body: some Scene {
///         WindowGroup {
///             I18nProvider(core: i18n) {
///                 ContentView()
///             }
///         }
///     }
/// }
/// ```
///
/// `.task { await store.load() }` modifier'ı view appear olduğunda otomatik
/// tetiklenir — `onAppear` yerine `task` kullanımı Swift Concurrency ile uyumludur,
/// view kaybolduğunda task otomatik iptal edilir.
public struct I18nProvider<Content: View>: View {

    @StateObject private var store: I18nStore
    private let content: () -> Content

    public init(core: BetterI18n, @ViewBuilder content: @escaping () -> Content) {
        _store = StateObject(wrappedValue: I18nStore(core: core))
        self.content = content
    }

    public var body: some View {
        content()
            .environmentObject(store)
            .task { await store.load() }
    }
}
