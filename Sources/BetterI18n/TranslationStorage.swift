import Foundation

/// Çeviri ve manifest verilerini kalıcı olarak saklamak için abstraction.
///
/// Protocol Sendable gerektiriyor çünkü `BetterI18n` actor boundary'lerinden geçer.
/// Tüm metodlar `async` — implementasyonlar gerekirse network/disk I/O yapabilir.
public protocol TranslationStorage: Sendable {
    func get(_ key: String) async -> String?
    func set(_ key: String, value: String) async
    func remove(_ key: String) async
}

// MARK: - UserDefaultsStorage

/// Standart UserDefaults kullanan storage. Ana uygulama için varsayılan seçim.
///
/// `actor` kullanılması sayesinde concurrent erişim güvenli hale gelir.
/// UserDefaults zaten thread-safe olmakla birlikte, actor isolation
/// yükü minimize eder ve Swift concurrency modeliyle uyumlu tutar.
public actor UserDefaultsStorage: TranslationStorage {
    private let defaults: UserDefaults

    public init() {
        self.defaults = .standard
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
