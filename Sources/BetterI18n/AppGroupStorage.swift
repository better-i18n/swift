import Foundation

/// App Group paylaşımlı UserDefaults kullanan storage.
///
/// Kullanım senaryosu: Ana uygulama çevirileri yazar, WidgetKit extension okur.
/// Storage key şeması JS SDK ile birebir aynı olduğu için Expo tarafından
/// yazılan değerler native widget tarafından direkt okunabilir:
///
///   "@better-i18n:messages:hellospace/safa:tr"
///
/// Widget extension'ının suiteName'i App Target ile aynı olmalıdır:
///   "group.com.hellospace.safa"
public actor AppGroupStorage: TranslationStorage {
    private let defaults: UserDefaults

    /// - Parameter suiteName: App Group identifier. Örn: "group.com.hellospace.safa"
    public init(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError(
                "[BetterI18n] App Group '\(suiteName)' bulunamadı. "
                + "Xcode'da Signing & Capabilities > App Groups ayarını kontrol edin."
            )
        }
        self.defaults = defaults
    }

    public func get(_ key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func set(_ key: String, value: String) {
        defaults.set(value, forKey: key)
    }

    public func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }
}
