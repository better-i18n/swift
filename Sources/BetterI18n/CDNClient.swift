import Foundation

/// better-i18n CDN'den manifest ve çeviri dosyalarını çeken istemci.
///
/// Retry stratejisi: exponential backoff — `2^attempt` saniye bekleme.
/// JS SDK'daki fetch options ile aynı: `Cache-Control: no-cache`.
/// URLSession inject edilebilir — test'lerde URLProtocol mock'u kullanmak için.
actor CDNClient {
    private let i18nConfig: I18nConfig
    let session: URLSession

    init(config: I18nConfig, session: URLSession? = nil) {
        self.i18nConfig = config
        if let session {
            self.session = session
        } else {
            let urlConfig = URLSessionConfiguration.default
            urlConfig.timeoutIntervalForRequest = config.fetchTimeout
            self.session = URLSession(configuration: urlConfig)
        }
    }

    // MARK: - Public fetch methods

    /// Proje manifest.json'unu CDN'den çeker ve decode eder.
    func fetchManifest() async throws -> ManifestResponse {
        let urlString = "\(i18nConfig.cdnBaseUrl)/\(i18nConfig.project)/manifest.json"
        guard let url = URL(string: urlString) else {
            throw I18nError.invalidURL(urlString)
        }
        let data = try await fetchDataWithRetry(url: url)
        do {
            return try JSONDecoder().decode(ManifestResponse.self, from: data)
        } catch {
            throw I18nError.decodingFailed(error.localizedDescription)
        }
    }

    /// Verilen URL'den çeviri JSON'unu çeker.
    /// URL, manifest.files[locale].url'den gelir — biz URL inşa ETMİYORUZ.
    func fetchTranslations(url urlString: String) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else {
            throw I18nError.invalidURL(urlString)
        }
        let data = try await fetchDataWithRetry(url: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw I18nError.invalidResponse
        }
        return json
    }

    // MARK: - Private helpers

    private func fetchDataWithRetry(url: URL) async throws -> Data {
        var lastError: Error?

        for attempt in 0 ... i18nConfig.retryCount {
            do {
                return try await fetchData(url: url)
            } catch is CancellationError {
                // Task iptal edildi — retry yapma, direkt fırlat
                throw CancellationError()
            } catch {
                lastError = error
                if i18nConfig.debug {
                    print("[BetterI18n] Fetch hatası (deneme \(attempt + 1)): \(error)")
                }
                if attempt < i18nConfig.retryCount {
                    // Exponential backoff: 1s, 2s, 4s...
                    let delayNs = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: delayNs)
                }
            }
        }

        throw lastError ?? I18nError.invalidResponse
    }

    private func fetchData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        // JS SDK ile aynı — CDN cache'ini bypass eder, her zaman güncel veri gelir
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw I18nError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw I18nError.httpError(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - I18nError

/// better-i18n SDK hata türleri.
public enum I18nError: Error, LocalizedError {
    case invalidURL(String)
    case httpError(Int)
    case invalidResponse
    case decodingFailed(String)
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "[BetterI18n] Geçersiz URL: \(url)"
        case .httpError(let code): return "[BetterI18n] HTTP hatası: \(code)"
        case .invalidResponse: return "[BetterI18n] Geçersiz yanıt formatı"
        case .decodingFailed(let msg): return "[BetterI18n] JSON decode hatası: \(msg)"
        case .notFound(let key): return "[BetterI18n] Bulunamadı: \(key)"
        }
    }
}
