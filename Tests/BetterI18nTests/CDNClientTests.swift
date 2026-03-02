import XCTest
@testable import BetterI18n

// MARK: - Mock URLProtocol

/// URLProtocol subclass — URLSession isteklerini intercept eder, gerçek ağa gitmez.
/// CDNClient inject edilebilir URLSession aldığı için test'te bu protocol kullanılır.
final class MockURLProtocol: URLProtocol {
    /// Test fixture'ı veya hata ayarlamak için kullanılır
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Test Fixtures

private let manifestJSON = """
{
    "projectSlug": "safa",
    "sourceLanguage": "tr",
    "languages": [
        {
            "code": "tr",
            "name": "Turkish",
            "nativeName": "Türkçe",
            "isSource": true,
            "flagUrl": "https://cdn.better-i18n.com/flags/tr.svg",
            "countryCode": "tr"
        },
        {
            "code": "en",
            "name": "English",
            "nativeName": "English",
            "isSource": false,
            "flagUrl": "https://cdn.better-i18n.com/flags/gb.svg",
            "countryCode": "gb"
        }
    ],
    "files": {
        "tr": { "url": "https://cdn.better-i18n.com/hellospace/safa/tr/translations.json" },
        "en": { "url": "https://cdn.better-i18n.com/hellospace/safa/en/translations.json" }
    },
    "updatedAt": "2026-03-01T00:00:00Z"
}
""".data(using: .utf8)!

private let translationsJSON = """
{
    "auth": {
        "login": {
            "title": "Giriş Yap",
            "button": "Oturum Aç"
        }
    }
}
""".data(using: .utf8)!

// MARK: - Helpers

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeConfig() -> I18nConfig {
    I18nConfig(project: "hellospace/safa", defaultLocale: "tr", debug: false)
}

private func makeI18n(session: URLSession) -> BetterI18n {
    BetterI18n(config: makeConfig(), session: session)
}

// MARK: - Tests

final class CDNClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
    }

    // MARK: - Manifest fetch

    func testFetchManifestSuccess() async throws {
        let session = makeMockSession()
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.hasSuffix("manifest.json") == true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, manifestJSON)
        }

        let i18n = makeI18n(session: session)
        let manifest = try await i18n.getManifest()

        XCTAssertEqual(manifest.languages.count, 2)
        XCTAssertEqual(manifest.languages[0].code, "tr")
        XCTAssertEqual(manifest.languages[1].code, "en")
        XCTAssertEqual(manifest.projectSlug, "safa")
        XCTAssertEqual(manifest.sourceLanguage, "tr")
    }

    func testFetchManifestHTTP404Throws() async throws {
        let session = makeMockSession()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let i18n = makeI18n(session: session)
        do {
            _ = try await i18n.getManifest()
            XCTFail("404 hata fırlatmalı")
        } catch I18nError.httpError(let code) {
            XCTAssertEqual(code, 404)
        }
    }

    // MARK: - Translation fetch

    func testFetchTranslationsSuccess() async throws {
        let session = makeMockSession()
        var callCount = 0

        MockURLProtocol.requestHandler = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            // İlk istek manifest, ikincisi translations
            return (response, callCount == 1 ? manifestJSON : translationsJSON)
        }

        let i18n = makeI18n(session: session)
        let messages = try await i18n.getMessages(locale: "tr")

        let auth = messages["auth"] as? [String: Any]
        let login = auth?["login"] as? [String: Any]
        XCTAssertEqual(login?["title"] as? String, "Giriş Yap")
        XCTAssertEqual(login?["button"] as? String, "Oturum Aç")
    }

    // MARK: - getLanguages

    func testGetLanguagesReturnsMappedOptions() async throws {
        let session = makeMockSession()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, manifestJSON)
        }

        let i18n = makeI18n(session: session)
        let languages = try await i18n.getLanguages()

        XCTAssertEqual(languages.count, 2)
        XCTAssertEqual(languages[0].code, "tr")
        XCTAssertEqual(languages[0].name, "Turkish")
        XCTAssertEqual(languages[0].nativeName, "Türkçe")
        XCTAssertEqual(languages[1].code, "en")
        // countryCode ManifestLanguage'de var ama LanguageOption'da yok
        XCTAssertNotNil(languages[1].flagUrl)
    }

    // MARK: - Storage fallback

    func testStorageFallbackWhenCDNFails() async throws {
        // Storage'a önceden manifest yaz
        let mockStorage = MockStorage()
        let config = I18nConfig(
            project: "hellospace/safa",
            defaultLocale: "tr",
            storage: mockStorage
        )
        let manifestData = try JSONEncoder().encode(
            ManifestResponse(
                projectSlug: "safa",
                sourceLanguage: "tr",
                languages: [ManifestLanguage(
                    code: "tr", name: "Turkish", nativeName: "Türkçe",
                    isSource: true, lastUpdated: nil, keyCount: nil,
                    flagUrl: nil, countryCode: nil
                )],
                files: nil,
                updatedAt: nil
            )
        )
        let key = "@better-i18n:manifest:hellospace/safa"
        await mockStorage.set(key, value: String(data: manifestData, encoding: .utf8)!)

        // CDN her zaman hata dönsün
        let session = makeMockSession()
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let i18n = BetterI18n(config: config, session: session)
        let manifest = try await i18n.getManifest()
        XCTAssertEqual(manifest.languages.count, 1)
        XCTAssertEqual(manifest.languages[0].code, "tr")
    }
}

// MARK: - MockStorage

/// Test için bellek içi storage implementasyonu.
/// `actor` olması sayesinde thread-safe — NSLock gerekmez.
actor MockStorage: TranslationStorage {
    private var store: [String: String] = [:]

    func get(_ key: String) -> String? {
        store[key]
    }

    func set(_ key: String, value: String) {
        store[key] = value
    }

    func remove(_ key: String) {
        store.removeValue(forKey: key)
    }
}
