import Foundation

/// Thread-safe, TTL tabanlı bellek cache'i.
/// `actor` olması sayesinde her erişim doğal olarak serialize edilir — lock gerekmez.
///
/// JS SDK'daki TtlCache ile aynı eviction stratejisi:
/// - Süresi dolmuş entry lazy olarak temizlenir (get() sırasında).
/// - Belirli bir max-size yoktur; kullanıcı sayısının küçük olduğu i18n senaryosunda yeterli.
actor TtlCache<T> {
    private struct Entry {
        let value: T
        let expiresAt: Date
    }

    private var store: [String: Entry] = [:]

    /// Cache'den değer döner. Süresi geçmişse nil döner ve lazy olarak siler.
    func get(_ key: String) -> T? {
        guard let entry = store[key] else { return nil }
        if Date() >= entry.expiresAt {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    /// Cache'e TTL ile değer ekler. ttlMs milisaniye cinsindendir.
    func set(_ key: String, value: T, ttlMs: Double) {
        let expiresAt = Date().addingTimeInterval(ttlMs / 1000.0)
        store[key] = Entry(value: value, expiresAt: expiresAt)
    }

    /// Belirli bir key'i cache'den siler.
    func invalidate(_ key: String) {
        store.removeValue(forKey: key)
    }

    /// Tüm cache'i temizler.
    func clear() {
        store.removeAll()
    }
}
