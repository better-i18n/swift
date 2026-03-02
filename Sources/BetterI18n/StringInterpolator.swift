import Foundation

/// `{key}` → değer formatındaki template string interpolasyonu.
///
/// JS SDK ile birebir aynı format: `"Merhaba, {name}!"` → `"Merhaba, Osman!"`
/// Tanımsız değişkenler olduğu gibi bırakılır (placeholder korunur).
enum StringInterpolator {
    /// Template içindeki `{key}` placeholder'larını variables dict'indeki değerlerle ikame eder.
    /// - Parameters:
    ///   - template: `{key}` formatında placeholder içeren string.
    ///   - variables: Anahtar-değer çiftleri.
    /// - Returns: İkame edilmiş string. Eksik key'ler olduğu gibi bırakılır.
    static func interpolate(_ template: String, variables: [String: String]) -> String {
        var result = template
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }
}
