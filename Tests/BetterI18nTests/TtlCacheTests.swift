import XCTest
@testable import BetterI18n

final class TtlCacheTests: XCTestCase {

    // MARK: - Basic get/set

    func testSetAndGet() async {
        let cache = TtlCache<String>()
        await cache.set("key1", value: "hello", ttlMs: 60_000)
        let result = await cache.get("key1")
        XCTAssertEqual(result, "hello")
    }

    func testMissingKeyReturnsNil() async {
        let cache = TtlCache<String>()
        let result = await cache.get("nonexistent")
        XCTAssertNil(result)
    }

    // MARK: - TTL eviction

    func testExpiredEntryReturnsNil() async throws {
        let cache = TtlCache<String>()
        // 10ms TTL — hemen expire olur
        await cache.set("key1", value: "value", ttlMs: 10)
        // 50ms bekle
        try await Task.sleep(nanoseconds: 50_000_000)
        let result = await cache.get("key1")
        XCTAssertNil(result, "Süresi geçmiş entry nil döndürmeli")
    }

    func testNonExpiredEntryStillPresent() async throws {
        let cache = TtlCache<String>()
        await cache.set("key1", value: "value", ttlMs: 5_000) // 5 saniye
        // 10ms bekle — daha dolmadı
        try await Task.sleep(nanoseconds: 10_000_000)
        let result = await cache.get("key1")
        XCTAssertEqual(result, "value")
    }

    // MARK: - Invalidate

    func testInvalidateRemovesKey() async {
        let cache = TtlCache<String>()
        await cache.set("key1", value: "value", ttlMs: 60_000)
        await cache.invalidate("key1")
        let result = await cache.get("key1")
        XCTAssertNil(result)
    }

    func testInvalidateNonexistentKeyIsNoop() async {
        let cache = TtlCache<String>()
        // Throw etmemeli, sessizce geçmeli
        await cache.invalidate("doesntExist")
    }

    // MARK: - Clear

    func testClearRemovesAllKeys() async {
        let cache = TtlCache<String>()
        await cache.set("key1", value: "a", ttlMs: 60_000)
        await cache.set("key2", value: "b", ttlMs: 60_000)
        await cache.set("key3", value: "c", ttlMs: 60_000)
        await cache.clear()
        let r1 = await cache.get("key1")
        let r2 = await cache.get("key2")
        let r3 = await cache.get("key3")
        XCTAssertNil(r1)
        XCTAssertNil(r2)
        XCTAssertNil(r3)
    }

    // MARK: - Overwrite

    func testSetOverwritesExistingKey() async {
        let cache = TtlCache<String>()
        await cache.set("key1", value: "original", ttlMs: 60_000)
        await cache.set("key1", value: "updated", ttlMs: 60_000)
        let result = await cache.get("key1")
        XCTAssertEqual(result, "updated")
    }

    // MARK: - Generic types

    func testIntValue() async {
        let cache = TtlCache<Int>()
        await cache.set("count", value: 42, ttlMs: 60_000)
        let result = await cache.get("count")
        XCTAssertEqual(result, 42)
    }
}
