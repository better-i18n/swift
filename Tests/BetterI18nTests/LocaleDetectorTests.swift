import XCTest
@testable import BetterI18n

final class LocaleDetectorTests: XCTestCase {

    private let availableCodes = ["tr", "en", "ar", "fr", "de", "es"]

    // MARK: - Exact match

    func testExactMatch() {
        let result = LocaleDetector.bestMatchLocale(["tr"], against: availableCodes)
        XCTAssertEqual(result, "tr")
    }

    func testExactMatchEnglish() {
        let result = LocaleDetector.bestMatchLocale(["en"], against: availableCodes)
        XCTAssertEqual(result, "en")
    }

    // MARK: - Base language match

    func testBCP47ToBase() {
        // Apple "tr-TR" döner, manifest "tr" içerir
        let result = LocaleDetector.bestMatchLocale(["tr-TR"], against: availableCodes)
        XCTAssertEqual(result, "tr")
    }

    func testBCP47EnUS() {
        let result = LocaleDetector.bestMatchLocale(["en-US"], against: availableCodes)
        XCTAssertEqual(result, "en")
    }

    func testBCP47ArSA() {
        let result = LocaleDetector.bestMatchLocale(["ar-SA"], against: availableCodes)
        XCTAssertEqual(result, "ar")
    }

    // MARK: - Priority (first match wins)

    func testFirstMatchWins() {
        // Cihazda Türkçe önce, İngilizce sonra — Türkçe dönmeli
        let result = LocaleDetector.bestMatchLocale(["tr-TR", "en-US"], against: availableCodes)
        XCTAssertEqual(result, "tr")
    }

    func testFallsToSecondWhenFirstMissing() {
        // Japonca yok, İngilizce var
        let result = LocaleDetector.bestMatchLocale(["ja-JP", "en-US"], against: availableCodes)
        XCTAssertEqual(result, "en")
    }

    // MARK: - No match

    func testNoMatchReturnsNil() {
        let result = LocaleDetector.bestMatchLocale(["ja", "zh"], against: availableCodes)
        XCTAssertNil(result)
    }

    func testEmptyDeviceLocalesReturnsNil() {
        let result = LocaleDetector.bestMatchLocale([], against: availableCodes)
        XCTAssertNil(result)
    }

    func testEmptyAvailableCodesReturnsNil() {
        let result = LocaleDetector.bestMatchLocale(["tr-TR", "en-US"], against: [])
        XCTAssertNil(result)
    }

    // MARK: - Edge cases

    func testSingleCharLocale() {
        // Geçersiz format — crash etmemeli
        let result = LocaleDetector.bestMatchLocale(["t"], against: availableCodes)
        XCTAssertNil(result)
    }

    func testUnderscoreFormat() {
        // Apple bazen "tr_TR" döner (nadiren) — base eşleşmesi yakalar
        // "tr_TR".components(separatedBy: "-").first → "tr_TR" (underscore'da split olmaz)
        // Bu durumda match olmaz — test davranışı belgeliyor
        let result = LocaleDetector.bestMatchLocale(["tr_TR"], against: availableCodes)
        // "tr_TR" tam eşleşmez, base "tr_TR" (dash yok) → eşleşmez
        XCTAssertNil(result, "Underscore format BCP 47 değil — eşleşmemeli")
    }
}
