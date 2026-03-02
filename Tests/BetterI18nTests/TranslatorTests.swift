import XCTest
@testable import BetterI18n

final class TranslatorTests: XCTestCase {

    // MARK: - Test Fixtures

    private func makeTranslator() -> Translator {
        let messages: [String: Any] = [
            "auth": [
                "login": [
                    "title": "Giriş Yap",
                    "button": "Oturum Aç",
                    "subtitle": "Hoş geldiniz, {name}!"
                ],
                "landing": [
                    "title": "Safa'ya Hoş Geldiniz"
                ]
            ],
            "home": [
                "title": "Ana Sayfa",
                "greeting": "Merhaba, {name}! {count} mesajın var."
            ],
            "simple": "Basit değer"
        ]
        return Translator(messages: messages, locale: "tr")
    }

    // MARK: - Dot-notation Resolution

    func testSimpleKey() {
        let t = makeTranslator()
        XCTAssertEqual(t("simple"), "Basit değer")
    }

    func testTwoLevelKey() {
        let t = makeTranslator()
        XCTAssertEqual(t("home.title"), "Ana Sayfa")
    }

    func testThreeLevelKey() {
        let t = makeTranslator()
        XCTAssertEqual(t("auth.login.title"), "Giriş Yap")
        XCTAssertEqual(t("auth.login.button"), "Oturum Aç")
        XCTAssertEqual(t("auth.landing.title"), "Safa'ya Hoş Geldiniz")
    }

    // MARK: - Fallback

    func testMissingKeyReturnsSameKey() {
        let t = makeTranslator()
        XCTAssertEqual(t("missing.key"), "missing.key")
        XCTAssertEqual(t("auth.nonexistent"), "auth.nonexistent")
        XCTAssertEqual(t("totally.missing.deep.key"), "totally.missing.deep.key")
    }

    func testIntermediateNodeAsKeyReturnsSelf() {
        // "auth" bir dict — string değil, fallback olmalı
        let t = makeTranslator()
        XCTAssertEqual(t("auth"), "auth")
    }

    // MARK: - Interpolation

    func testSingleVariableInterpolation() {
        let t = makeTranslator()
        let result = t("auth.login.subtitle", ["name": "Osman"])
        XCTAssertEqual(result, "Hoş geldiniz, Osman!")
    }

    func testMultipleVariableInterpolation() {
        let t = makeTranslator()
        let result = t("home.greeting", ["name": "Ali", "count": "5"])
        XCTAssertEqual(result, "Merhaba, Ali! 5 mesajın var.")
    }

    func testMissingVariableKeepsPlaceholder() {
        let t = makeTranslator()
        // "name" sağlanmadı — placeholder korunmalı
        let result = t("auth.login.subtitle", [:])
        XCTAssertEqual(result, "Hoş geldiniz, {name}!")
    }

    func testInterpolationOnMissingKeyReturnsKey() {
        let t = makeTranslator()
        let result = t("missing.key", ["name": "Test"])
        XCTAssertEqual(result, "missing.key")
    }

    // MARK: - Subscript

    func testSubscriptAccess() {
        let t = makeTranslator()
        XCTAssertEqual(t["auth.login.title"], "Giriş Yap")
        XCTAssertEqual(t["missing.key"], "missing.key")
    }

    // MARK: - callAsFunction Syntax

    func testCallAsFunctionSyntax() {
        let t = makeTranslator()
        // callAsFunction olduğu için doğrudan çağrılabilir
        XCTAssertEqual(t("home.title"), "Ana Sayfa")
    }
}
